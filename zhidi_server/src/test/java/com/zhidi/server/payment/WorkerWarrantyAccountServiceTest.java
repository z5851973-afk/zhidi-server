package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.common.error.BusinessException;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class WorkerWarrantyAccountServiceTest {

	private final WorkerWarrantyAccountRepository accounts =
		mock(WorkerWarrantyAccountRepository.class);
	private final WorkerWarrantyContributionRepository contributions =
		mock(WorkerWarrantyContributionRepository.class);
	private final WorkerWarrantyLedgerEntryRepository ledger =
		mock(WorkerWarrantyLedgerEntryRepository.class);
	private WorkerWarrantyAccountService service;
	private UUID workerId;

	@BeforeEach
	void setUp() {
		service = new WorkerWarrantyAccountService(accounts, contributions, ledger);
		workerId = UUID.randomUUID();
		when(contributions.findOutstandingByWorkerUserId(workerId))
			.thenReturn(List.of());
		when(accounts.saveAndFlush(any())).thenAnswer(invocation -> invocation.getArgument(0));
		when(contributions.saveAndFlush(any()))
			.thenAnswer(invocation -> invocation.getArgument(0));
	}

	@Test
	void contributionIsTenPercentUntilAccountReachesTenThousandCap() {
		when(accounts.findByWorkerUserId(workerId)).thenReturn(Optional.empty());
		assertThat(service.calculateDue(workerId, new BigDecimal("10840.00")))
			.isEqualByComparingTo("1084.00");

		WorkerWarrantyAccount account = WorkerWarrantyAccount.create(workerId);
		account.credit(new BigDecimal("9500.00"));
		when(accounts.findByWorkerUserId(workerId)).thenReturn(Optional.of(account));
		assertThat(service.calculateDue(workerId, new BigDecimal("10840.00")))
			.isEqualByComparingTo("500.00");

		account.credit(new BigDecimal("500.00"));
		assertThat(service.calculateDue(workerId, new BigDecimal("10840.00")))
			.isZero();
	}

	@Test
	void paymentOrderCreatesAtMostOneContribution() {
		UUID paymentOrderId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		when(accounts.findByWorkerUserIdForUpdate(workerId))
			.thenReturn(Optional.empty());
		when(contributions.findByPaymentOrderId(paymentOrderId))
			.thenReturn(Optional.empty());

		service.createContributionForPaidOrder(workerId, paymentOrderId, bookingId,
			new BigDecimal("1000.00"));
		verify(contributions).saveAndFlush(any(WorkerWarrantyContribution.class));

		WorkerWarrantyContribution existing = WorkerWarrantyContribution.create(
			workerId, paymentOrderId, bookingId, new BigDecimal("100.00"));
		when(contributions.findByPaymentOrderId(paymentOrderId))
			.thenReturn(Optional.of(existing));
		service.createContributionForPaidOrder(workerId, paymentOrderId, bookingId,
			new BigDecimal("1000.00"));

		verify(contributions, times(1))
			.saveAndFlush(any(WorkerWarrantyContribution.class));
	}

	@Test
	void adminVerificationCreditsAccountAndLedgerExactlyOnce() {
		UUID contributionId = UUID.randomUUID();
		UUID adminId = UUID.randomUUID();
		WorkerWarrantyAccount account = WorkerWarrantyAccount.create(workerId);
		WorkerWarrantyContribution contribution = WorkerWarrantyContribution.create(
			workerId, UUID.randomUUID(), UUID.randomUUID(), new BigDecimal("1084.00"));
		contribution.report("对公转账", "warranty-ref-1");
		when(contributions.findById(contributionId))
			.thenReturn(Optional.of(contribution));
		when(accounts.findByWorkerUserIdForUpdate(workerId))
			.thenReturn(Optional.of(account));

		service.verifyContribution(adminId, contributionId, true, null);
		service.verifyContribution(adminId, contributionId, true, null);

		assertThat(account.getEffectiveBalance()).isEqualByComparingTo("1084.00");
		assertThat(contribution.getStatus())
			.isEqualTo(WorkerWarrantyContributionStatus.VERIFIED);
		verify(ledger, times(1)).saveAndFlush(any(WorkerWarrantyLedgerEntry.class));
	}

	@Test
	void rejectionDoesNotCreditAccount() {
		UUID contributionId = UUID.randomUUID();
		WorkerWarrantyContribution contribution = WorkerWarrantyContribution.create(
			workerId, UUID.randomUUID(), UUID.randomUUID(), new BigDecimal("100.00"));
		contribution.report("对公转账", "bad-ref");
		when(contributions.findById(contributionId))
			.thenReturn(Optional.of(contribution));

		service.verifyContribution(UUID.randomUUID(), contributionId, false,
			"未查询到款项");

		assertThat(contribution.getStatus())
			.isEqualTo(WorkerWarrantyContributionStatus.REJECTED);
		verify(accounts, never()).saveAndFlush(any());
		verify(ledger, never()).saveAndFlush(any());
	}

	@Test
	void releasePendingAccountCannotAcceptNewJobs() {
		WorkerWarrantyAccount account = WorkerWarrantyAccount.create(workerId);
		account.requestRelease();
		when(accounts.findByWorkerUserId(workerId)).thenReturn(Optional.of(account));

		assertThat(service.canAcceptNewJobs(workerId)).isFalse();
	}

	@Test
	void afterSaleDeductionCreatesExactTopUpObligationAndBlocksNewJobs() {
		UUID afterSaleId = UUID.randomUUID();
		WorkerWarrantyAccount account = fundedAccount("100.00");
		AtomicReference<WorkerWarrantyContribution> stored =
			stubAfterSaleContribution(afterSaleId);
		when(accounts.findByWorkerUserIdForUpdate(workerId))
			.thenReturn(Optional.of(account));
		when(accounts.findByWorkerUserId(workerId)).thenReturn(Optional.of(account));

		WorkerWarrantyAccountResponse response = service.deductForAfterSale(
			workerId, afterSaleId, new BigDecimal("10.00"), "售后扣减");

		assertThat(account.getEffectiveBalance()).isEqualByComparingTo("90.00");
		assertThat(response.outstandingAmount()).isEqualByComparingTo("10.00");
		assertThat(response.status())
			.isEqualTo(WorkerWarrantyAccountStatus.TOP_UP_REQUIRED);
		assertThat(response.canAcceptNewJobs()).isFalse();
		assertThat(stored.get()).isNotNull();
		assertThat(stored.get().getAfterSaleId()).isEqualTo(afterSaleId);
		assertThat(stored.get().getAmountDue()).isEqualByComparingTo("10.00");
		assertThat(service.canAcceptNewJobs(workerId)).isFalse();
		verify(ledger).saveAndFlush(any(WorkerWarrantyLedgerEntry.class));
	}

	@Test
	void repeatedAfterSaleDeductionReturnsSameObligationWithoutDoubleDeducting() {
		UUID afterSaleId = UUID.randomUUID();
		WorkerWarrantyAccount account = fundedAccount("100.00");
		AtomicReference<WorkerWarrantyContribution> stored =
			stubAfterSaleContribution(afterSaleId);
		when(accounts.findByWorkerUserIdForUpdate(workerId))
			.thenReturn(Optional.of(account));

		service.deductForAfterSale(workerId, afterSaleId,
			new BigDecimal("10.00"), "第一次处理");
		WorkerWarrantyAccountResponse repeated = service.deductForAfterSale(
			workerId, afterSaleId, new BigDecimal("10.00"), "重复处理");

		assertThat(account.getEffectiveBalance()).isEqualByComparingTo("90.00");
		assertThat(repeated.outstandingAmount()).isEqualByComparingTo("10.00");
		verify(contributions, times(1))
			.saveAndFlush(any(WorkerWarrantyContribution.class));
		verify(ledger, times(1)).saveAndFlush(any(WorkerWarrantyLedgerEntry.class));
	}

	@Test
	void ensureTopUpReturnsReportedObligationWithoutCreatingAnotherOne() {
		UUID afterSaleId = UUID.randomUUID();
		WorkerWarrantyAccount account = fundedAccount("20.00");
		account.deduct(new BigDecimal("10.00"));
		WorkerWarrantyContribution reported =
			WorkerWarrantyContribution.createForAfterSaleDeduction(
				workerId, afterSaleId, new BigDecimal("10.00"));
		reported.report("BANK_TRANSFER", "reported-top-up");
		when(accounts.findByWorkerUserIdForUpdate(workerId))
			.thenReturn(Optional.of(account));
		when(contributions.findOutstandingByWorkerUserId(workerId))
			.thenReturn(List.of(reported));

		WorkerWarrantyContributionResponse response =
			service.getOrCreateTopUpObligation(workerId);

		assertThat(response.status())
			.isEqualTo(WorkerWarrantyContributionStatus.REPORTED);
		assertThat(response.afterSaleId()).isEqualTo(afterSaleId);
		verify(contributions, never()).saveAndFlush(any());
	}

	@Test
	void legacyTopUpRecoveryUsesDeductionLedgerAmountNotClientInput() {
		UUID afterSaleId = UUID.randomUUID();
		WorkerWarrantyAccount account = fundedAccount("20.00");
		account.deduct(new BigDecimal("10.00"));
		WorkerWarrantyLedgerEntry deduction = WorkerWarrantyLedgerEntry.deduction(
			account, afterSaleId, new BigDecimal("10.00"), "历史售后扣减");
		AtomicReference<WorkerWarrantyContribution> stored =
			stubAfterSaleContribution(afterSaleId);
		when(accounts.findByWorkerUserIdForUpdate(workerId))
			.thenReturn(Optional.of(account));
		when(ledger.findByWorkerUserIdAndEntryTypeAndSourceTypeOrderByCreatedAtDesc(
			workerId, WorkerWarrantyLedgerEntryType.DEDUCTION, "AFTER_SALE"))
			.thenReturn(List.of(deduction));

		WorkerWarrantyContributionResponse response =
			service.getOrCreateTopUpObligation(workerId);
		WorkerWarrantyContributionResponse repeated =
			service.getOrCreateTopUpObligation(workerId);

		assertThat(response.amountDue()).isEqualByComparingTo("10.00");
		assertThat(response.afterSaleId()).isEqualTo(afterSaleId);
		assertThat(repeated.afterSaleId()).isEqualTo(response.afterSaleId());
		assertThat(repeated.amountDue()).isEqualByComparingTo(response.amountDue());
		assertThat(stored.get()).isNotNull();
		assertThat(account.getEffectiveBalance()).isEqualByComparingTo("10.00");
		verify(contributions, times(1))
			.saveAndFlush(any(WorkerWarrantyContribution.class));
		verify(ledger, never()).saveAndFlush(any());
	}

	@Test
	void verifyingAfterSaleTopUpRestoresBalanceAndReactivatesAccount() {
		UUID afterSaleId = UUID.randomUUID();
		UUID contributionId = UUID.randomUUID();
		UUID adminId = UUID.randomUUID();
		WorkerWarrantyAccount account = fundedAccount("20.00");
		account.deduct(new BigDecimal("10.00"));
		WorkerWarrantyContribution contribution =
			WorkerWarrantyContribution.createForAfterSaleDeduction(
				workerId, afterSaleId, new BigDecimal("10.00"));
		contribution.report("BANK_TRANSFER", "verified-top-up");
		when(contributions.findById(contributionId))
			.thenReturn(Optional.of(contribution));
		when(accounts.findByWorkerUserIdForUpdate(workerId))
			.thenReturn(Optional.of(account));
		when(accounts.findByWorkerUserId(workerId)).thenReturn(Optional.of(account));
		when(contributions.findOutstandingByWorkerUserId(workerId))
			.thenAnswer(invocation -> contribution.getStatus()
				== WorkerWarrantyContributionStatus.VERIFIED
					? List.of() : List.of(contribution));

		service.verifyContribution(adminId, contributionId, true, null);

		assertThat(account.getEffectiveBalance()).isEqualByComparingTo("20.00");
		assertThat(account.getStatus())
			.isEqualTo(WorkerWarrantyAccountStatus.ACTIVE);
		assertThat(service.canAcceptNewJobs(workerId)).isTrue();
	}

	@Test
	void workerCannotReportAnotherWorkersContribution() {
		UUID contributionId = UUID.randomUUID();
		WorkerWarrantyContribution anotherWorkersContribution =
			WorkerWarrantyContribution.createForAfterSaleDeduction(
				UUID.randomUUID(), UUID.randomUUID(), new BigDecimal("10.00"));
		when(contributions.findById(contributionId))
			.thenReturn(Optional.of(anotherWorkersContribution));

		assertThatThrownBy(() -> service.reportContribution(
			workerId, contributionId, "BANK_TRANSFER", "not-mine"))
			.isInstanceOfSatisfying(BusinessException.class,
				ex -> assertThat(ex.code())
					.isEqualTo("WARRANTY_CONTRIBUTION_NOT_FOUND"));
		verify(contributions, never()).saveAndFlush(any());
	}

	private WorkerWarrantyAccount fundedAccount(String amount) {
		WorkerWarrantyAccount account = WorkerWarrantyAccount.create(workerId);
		account.credit(new BigDecimal(amount));
		return account;
	}

	private AtomicReference<WorkerWarrantyContribution>
			stubAfterSaleContribution(UUID afterSaleId) {
		AtomicReference<WorkerWarrantyContribution> stored = new AtomicReference<>();
		when(contributions.findByAfterSaleId(afterSaleId))
			.thenAnswer(invocation -> Optional.ofNullable(stored.get()));
		when(contributions.findOutstandingByWorkerUserId(workerId))
			.thenAnswer(invocation -> {
				WorkerWarrantyContribution contribution = stored.get();
				if (contribution == null || contribution.getStatus()
						== WorkerWarrantyContributionStatus.VERIFIED) {
					return List.of();
				}
				return List.of(contribution);
			});
		when(contributions.saveAndFlush(any(WorkerWarrantyContribution.class)))
			.thenAnswer(invocation -> {
				WorkerWarrantyContribution contribution = invocation.getArgument(0);
				stored.compareAndSet(null, contribution);
				return stored.get();
			});
		return stored;
	}
}
