package com.zhidi.server.payment;

import com.zhidi.server.common.error.BusinessException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class WorkerWarrantyAccountService {

	private static final BigDecimal CONTRIBUTION_RATE = new BigDecimal("0.10");
	private static final String AFTER_SALE_SOURCE_TYPE = "AFTER_SALE";
	private final WorkerWarrantyAccountRepository accounts;
	private final WorkerWarrantyContributionRepository contributions;
	private final WorkerWarrantyLedgerEntryRepository ledger;

	public WorkerWarrantyAccountService(WorkerWarrantyAccountRepository accounts,
			WorkerWarrantyContributionRepository contributions,
			WorkerWarrantyLedgerEntryRepository ledger) {
		this.accounts = accounts;
		this.contributions = contributions;
		this.ledger = ledger;
	}

	@Transactional(readOnly = true)
	public BigDecimal calculateDue(UUID workerUserId, BigDecimal quoteAmount) {
		WorkerWarrantyAccount account = accounts.findByWorkerUserId(workerUserId)
			.orElse(null);
		return calculateDue(workerUserId, quoteAmount, account);
	}

	private BigDecimal calculateDue(UUID workerUserId, BigDecimal quoteAmount,
			WorkerWarrantyAccount account) {
		BigDecimal balance = account == null
			? BigDecimal.ZERO : account.getEffectiveBalance();
		BigDecimal cap = account == null
			? WorkerWarrantyAccount.DEFAULT_CAP : account.getCapAmount();
		BigDecimal outstanding = contributions.findOutstandingByWorkerUserId(workerUserId)
			.stream()
			.map(WorkerWarrantyContribution::getAmountDue)
			.reduce(BigDecimal.ZERO, BigDecimal::add);
		BigDecimal gap = cap.subtract(balance).subtract(outstanding)
			.max(BigDecimal.ZERO);
		BigDecimal tenPercent = quoteAmount.multiply(CONTRIBUTION_RATE)
			.setScale(2, RoundingMode.HALF_UP);
		return tenPercent.min(gap).setScale(2, RoundingMode.HALF_UP);
	}

	@Transactional
	public Optional<WorkerWarrantyContribution> createContributionForPaidOrder(
			UUID workerUserId, UUID paymentOrderId, UUID bookingId,
			BigDecimal quoteAmount) {
		Optional<WorkerWarrantyContribution> existing =
			contributions.findByPaymentOrderId(paymentOrderId);
		if (existing.isPresent()) return existing;
		WorkerWarrantyAccount account = accounts
			.findByWorkerUserIdForUpdate(workerUserId).orElse(null);
		BigDecimal amountDue = calculateDue(workerUserId, quoteAmount, account);
		if (amountDue.compareTo(BigDecimal.ZERO) <= 0) return Optional.empty();
		if (account == null) {
			account = accounts.saveAndFlush(WorkerWarrantyAccount.create(workerUserId));
		}
		account.requireTopUp();
		accounts.saveAndFlush(account);
		return Optional.of(contributions.saveAndFlush(
			WorkerWarrantyContribution.createForPaidOrder(workerUserId,
				paymentOrderId, bookingId, amountDue)));
	}

	/**
	 * Returns the current outstanding obligation, or reconstructs an obligation
	 * from immutable after-sale deduction ledger entries created before V31.
	 * The request deliberately contains neither worker id nor amount: both are
	 * derived from the authenticated principal and server-side ledger.
	 */
	@Transactional
	public WorkerWarrantyContributionResponse getOrCreateTopUpObligation(
			UUID workerUserId) {
		WorkerWarrantyAccount account = accounts
			.findByWorkerUserIdForUpdate(workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WARRANTY_ACCOUNT_NOT_FOUND", "工人质保金账户不存在"));
		List<WorkerWarrantyContribution> outstanding =
			contributions.findOutstandingByWorkerUserId(workerUserId);
		if (!outstanding.isEmpty()) {
			return WorkerWarrantyContributionResponse.from(
				preferredOutstanding(outstanding));
		}
		if (account.getStatus() != WorkerWarrantyAccountStatus.TOP_UP_REQUIRED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WARRANTY_TOP_UP_NOT_REQUIRED", "当前没有待补履约质保金");
		}

		List<WorkerWarrantyLedgerEntry> deductions = ledger
			.findByWorkerUserIdAndEntryTypeAndSourceTypeOrderByCreatedAtDesc(
				workerUserId, WorkerWarrantyLedgerEntryType.DEDUCTION,
				AFTER_SALE_SOURCE_TYPE);
		for (WorkerWarrantyLedgerEntry deduction : deductions) {
			UUID afterSaleId = parseAfterSaleId(deduction.getSourceId());
			if (contributions.findByAfterSaleId(afterSaleId).isEmpty()) {
				contributions.saveAndFlush(
					WorkerWarrantyContribution.createForAfterSaleDeduction(
						workerUserId, afterSaleId, deduction.getAmount()));
			}
		}
		outstanding = contributions.findOutstandingByWorkerUserId(workerUserId);
		if (outstanding.isEmpty()) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WARRANTY_TOP_UP_OBLIGATION_NOT_FOUND",
				"未找到可核对的售后扣减记录，请联系平台处理");
		}
		return WorkerWarrantyContributionResponse.from(
			preferredOutstanding(outstanding));
	}

	@Transactional
	public WorkerWarrantyContribution reportContribution(UUID workerUserId,
			UUID contributionId, String channel, String reference) {
		WorkerWarrantyContribution contribution = findContribution(contributionId);
		if (!contribution.getWorkerUserId().equals(workerUserId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"WARRANTY_CONTRIBUTION_NOT_FOUND", "质保金补充义务不存在");
		}
		if (contributions.existsByPaymentReferenceAndIdNot(
				reference == null ? null : reference.trim(), contributionId)) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"PAYMENT_REFERENCE_ALREADY_USED", "交易参考号已使用");
		}
		try {
			contribution.report(channel, reference);
		} catch (IllegalArgumentException ex) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_WARRANTY_PAYMENT_REPORT", ex.getMessage());
		} catch (IllegalStateException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", ex.getMessage());
		}
		return contributions.saveAndFlush(contribution);
	}

	@Transactional
	public WorkerWarrantyContribution verifyContribution(UUID adminUserId,
			UUID contributionId, boolean approved, String reason) {
		WorkerWarrantyContribution contribution = findContribution(contributionId);
		if (approved && contribution.getStatus()
				== WorkerWarrantyContributionStatus.VERIFIED) {
			return contribution;
		}
		try {
			if (!approved) {
				contribution.reject(adminUserId, reason);
				return contributions.saveAndFlush(contribution);
			}
			contribution.verify(adminUserId);
			WorkerWarrantyAccount account = accounts
				.findByWorkerUserIdForUpdate(contribution.getWorkerUserId())
				.orElseGet(() -> accounts.saveAndFlush(
					WorkerWarrantyAccount.create(contribution.getWorkerUserId())));
			account.credit(contribution.getAmountDue());
			if (contributions.findOutstandingByWorkerUserId(
					contribution.getWorkerUserId()).isEmpty()) {
				account.activate();
			}
			contributions.saveAndFlush(contribution);
			accounts.saveAndFlush(account);
			ledger.saveAndFlush(WorkerWarrantyLedgerEntry.contribution(
				account, contribution, adminUserId));
			return contribution;
		} catch (IllegalArgumentException ex) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_WARRANTY_VERIFICATION", ex.getMessage());
		} catch (IllegalStateException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", ex.getMessage());
		}
	}

	@Transactional(readOnly = true)
	public boolean hasOutstandingContribution(UUID workerUserId) {
		return !contributions.findOutstandingByWorkerUserId(workerUserId).isEmpty();
	}

	@Transactional(readOnly = true)
	public boolean canAcceptNewJobs(UUID workerUserId) {
		if (hasOutstandingContribution(workerUserId)) return false;
		return accounts.findByWorkerUserId(workerUserId)
			.map(account -> account.getStatus() == WorkerWarrantyAccountStatus.ACTIVE)
			.orElse(true);
	}

	/**
	 * Serializes the accept-new-job decision with warranty deductions. Callers
	 * must invoke this before locking or mutating a booking so every competing
	 * flow acquires the warranty account lock first.
	 */
	@Transactional
	public boolean canAcceptNewJobsForUpdate(UUID workerUserId) {
		Optional<WorkerWarrantyAccount> account =
			accounts.findByWorkerUserIdForUpdate(workerUserId);
		if (account.isEmpty()) return true;
		if (!contributions.findOutstandingByWorkerUserId(workerUserId).isEmpty()) {
			return false;
		}
		return account.get().getStatus() == WorkerWarrantyAccountStatus.ACTIVE;
	}

	@Transactional(readOnly = true)
	public WorkerWarrantyAccountResponse getAccount(UUID workerUserId) {
		List<WorkerWarrantyContribution> outstanding =
			contributions.findOutstandingByWorkerUserId(workerUserId);
		BigDecimal amount = outstanding.stream()
			.map(WorkerWarrantyContribution::getAmountDue)
			.reduce(BigDecimal.ZERO, BigDecimal::add)
			.setScale(2, RoundingMode.HALF_UP);
		return accounts.findByWorkerUserId(workerUserId)
			.map(account -> WorkerWarrantyAccountResponse.from(account, amount))
			.orElseGet(() -> WorkerWarrantyAccountResponse.empty(workerUserId));
	}

	@Transactional(readOnly = true)
	public List<WorkerWarrantyContributionResponse> listContributions(
			UUID workerUserId) {
		return contributions.findByWorkerUserIdOrderByCreatedAtDesc(workerUserId)
			.stream().map(WorkerWarrantyContributionResponse::from).toList();
	}

	@Transactional(readOnly = true)
	public Page<WorkerWarrantyContributionResponse> listContributionsForAdmin(
			WorkerWarrantyContributionStatus status, Pageable pageable) {
		Page<WorkerWarrantyContribution> page = status == null
			? contributions.findAll(pageable)
			: contributions.findByStatus(status, pageable);
		return page.map(WorkerWarrantyContributionResponse::from);
	}

	@Transactional
	public WorkerWarrantyContributionResponse reportContributionResponse(
			UUID workerUserId, UUID contributionId, String channel,
			String reference) {
		return WorkerWarrantyContributionResponse.from(reportContribution(
			workerUserId, contributionId, channel, reference));
	}

	@Transactional
	public WorkerWarrantyContributionResponse verifyContributionResponse(
			UUID adminUserId, UUID contributionId, boolean approved, String reason) {
		return WorkerWarrantyContributionResponse.from(verifyContribution(
			adminUserId, contributionId, approved, reason));
	}

	@Transactional
	public WorkerWarrantyAccountResponse requestRelease(UUID workerUserId) {
		WorkerWarrantyAccount account = accounts.findByWorkerUserIdForUpdate(workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WARRANTY_ACCOUNT_NOT_FOUND", "质保金账户不存在"));
		if (hasOutstandingContribution(workerUserId)) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WARRANTY_TOP_UP_REQUIRED", "存在待补质保金，不能申请释放");
		}
		try {
			account.requestRelease();
		} catch (IllegalStateException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", ex.getMessage());
		}
		accounts.saveAndFlush(account);
		return WorkerWarrantyAccountResponse.from(
			account, BigDecimal.ZERO.setScale(2));
	}

	@Transactional
	public WorkerWarrantyAccountResponse deductForAfterSale(UUID workerUserId,
			UUID afterSaleId, BigDecimal amount, String reason) {
		WorkerWarrantyAccount account = accounts.findByWorkerUserIdForUpdate(workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WARRANTY_ACCOUNT_NOT_FOUND", "工人质保金账户不存在"));
		Optional<WorkerWarrantyContribution> existing =
			contributions.findByAfterSaleId(afterSaleId);
		if (existing.isPresent()) {
			assertContributionOwner(workerUserId, existing.get());
			return accountResponse(account, workerUserId);
		}

		Optional<WorkerWarrantyLedgerEntry> legacyDeduction =
			ledger.findFirstBySourceTypeAndSourceIdOrderByCreatedAtDesc(
				AFTER_SALE_SOURCE_TYPE, afterSaleId.toString());
		if (legacyDeduction.isPresent()) {
			WorkerWarrantyLedgerEntry deduction = legacyDeduction.get();
			if (!deduction.getWorkerUserId().equals(workerUserId)) {
				throw new BusinessException(HttpStatus.CONFLICT,
					"WARRANTY_TOP_UP_SOURCE_CONFLICT", "售后扣减归属不一致");
			}
			account.requireTopUp();
			accounts.saveAndFlush(account);
			contributions.saveAndFlush(
				WorkerWarrantyContribution.createForAfterSaleDeduction(
					workerUserId, afterSaleId, deduction.getAmount()));
			return accountResponse(account, workerUserId);
		}
		try {
			account.deduct(amount);
		} catch (IllegalArgumentException ex) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_DEDUCTION_AMOUNT", ex.getMessage());
		}
		accounts.saveAndFlush(account);
		ledger.saveAndFlush(WorkerWarrantyLedgerEntry.deduction(
			account, afterSaleId, WorkerWarrantyAccount.money(amount), reason));
		contributions.saveAndFlush(
			WorkerWarrantyContribution.createForAfterSaleDeduction(
				workerUserId, afterSaleId, WorkerWarrantyAccount.money(amount)));
		return accountResponse(account, workerUserId);
	}

	private WorkerWarrantyAccountResponse accountResponse(
			WorkerWarrantyAccount account, UUID workerUserId) {
		BigDecimal outstanding = contributions
			.findOutstandingByWorkerUserId(workerUserId).stream()
			.map(WorkerWarrantyContribution::getAmountDue)
			.reduce(BigDecimal.ZERO, BigDecimal::add)
			.setScale(2, RoundingMode.HALF_UP);
		return WorkerWarrantyAccountResponse.from(account, outstanding);
	}

	private WorkerWarrantyContribution preferredOutstanding(
			List<WorkerWarrantyContribution> outstanding) {
		return outstanding.stream()
			.filter(item -> item.getStatus()
				== WorkerWarrantyContributionStatus.REPORTED)
			.findFirst().orElse(outstanding.getFirst());
	}

	private UUID parseAfterSaleId(String sourceId) {
		try {
			return UUID.fromString(sourceId);
		} catch (IllegalArgumentException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WARRANTY_TOP_UP_SOURCE_INVALID", "售后扣减流水来源无效");
		}
	}

	private void assertContributionOwner(UUID workerUserId,
			WorkerWarrantyContribution contribution) {
		if (!contribution.getWorkerUserId().equals(workerUserId)) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WARRANTY_TOP_UP_SOURCE_CONFLICT", "售后补缴义务归属不一致");
		}
	}

	private WorkerWarrantyContribution findContribution(UUID contributionId) {
		return contributions.findById(contributionId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WARRANTY_CONTRIBUTION_NOT_FOUND", "质保金补充义务不存在"));
	}
}
