package com.zhidi.server.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.payment.AfterSale;
import com.zhidi.server.payment.AfterSaleEventRepository;
import com.zhidi.server.payment.AfterSaleRepository;
import com.zhidi.server.payment.AfterSaleResponse;
import com.zhidi.server.payment.AfterSaleService;
import com.zhidi.server.payment.AfterSaleStatus;
import com.zhidi.server.payment.AfterSaleType;
import com.zhidi.server.payment.PaymentOrder;
import com.zhidi.server.payment.PaymentOrderRepository;
import com.zhidi.server.payment.WorkerWarrantyAccount;
import com.zhidi.server.payment.WorkerWarrantyAccountRepository;
import com.zhidi.server.payment.WorkerWarrantyAccountService;
import com.zhidi.server.payment.WorkerWarrantyContributionRepository;
import com.zhidi.server.payment.WorkerWarrantyLedgerEntryRepository;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@SpringBootTest
@ActiveProfiles("test")
class BookingWarrantyConcurrencyIntegrationTest extends MySqlContainerSupport {

	@Autowired BookingService bookingsService;
	@MockitoSpyBean WorkerWarrantyAccountService warrantyService;
	@Autowired AfterSaleService afterSaleService;
	@Autowired BookingRepository bookings;
	@Autowired VisitProposalRepository visitProposals;
	@Autowired ServiceRequestRepository serviceRequests;
	@Autowired WorkerProfileRepository workerProfiles;
	@Autowired OwnerProfileRepository ownerProfiles;
	@Autowired UserRepository users;
	@Autowired AfterSaleRepository afterSales;
	@Autowired AfterSaleEventRepository afterSaleEvents;
	@Autowired PaymentOrderRepository paymentOrders;
	@Autowired WorkerWarrantyAccountRepository warrantyAccounts;
	@Autowired WorkerWarrantyContributionRepository warrantyContributions;
	@Autowired WorkerWarrantyLedgerEntryRepository warrantyLedger;
	@Autowired PlatformTransactionManager transactionManager;

	@BeforeEach
	void cleanDatabase() {
		warrantyContributions.deleteAll();
		warrantyLedger.deleteAll();
		warrantyAccounts.deleteAll();
		afterSaleEvents.deleteAll();
		afterSales.deleteAll();
		paymentOrders.deleteAll();
		visitProposals.deleteAll();
		bookings.deleteAll();
		serviceRequests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();
	}

	@Test
	void afterSaleDeductionHoldingAccountLockPreventsConcurrentAccept()
			throws Exception {
		User owner = createUser("13800138201", UserRole.OWNER);
		User worker = createUser("13800138202", UserRole.WORKER);
		User admin = createUser("13800138203", UserRole.ADMIN);
		workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(), "锁测试师傅",
			"成都", "木工", 8, new BigDecimal("600.00"), "木作施工"));
		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(), "锁测试业主",
			"成都", "旧房改造", "武侯区", new BigDecimal("88.00")));
		BookingResponse booking = bookingsService.create(owner.getId(),
			new BookingRequest(worker.getId(), "木工", "成都", "武侯区",
				new BigDecimal("88.00"), (short) 3, (short) 2, (short) 1,
				(short) 2, "并发接单门禁"));
		WorkerWarrantyAccount account = WorkerWarrantyAccount.create(worker.getId());
		account.credit(new BigDecimal("100.00"));
		warrantyAccounts.saveAndFlush(account);
		paymentOrders.saveAndFlush(PaymentOrder.createSplitOffline(
			booking.id(), owner.getId(), worker.getId(), null,
			new BigDecimal("1000.00")));
		AfterSale afterSale = afterSales.saveAndFlush(AfterSale.create(
			booking.id(), owner.getId(), worker.getId(), AfterSaleType.DISPUTE,
			"售后扣减并发测试", List.of()));
		afterSaleService.adminAccept(admin.getId(), afterSale.getId());

		CountDownLatch deductionAppliedWithTransactionOpen = new CountDownLatch(1);
		CountDownLatch allowResolutionCommit = new CountDownLatch(1);
		CountDownLatch acceptStarted = new CountDownLatch(1);
		doAnswer(invocation -> {
			Object response = invocation.callRealMethod();
			deductionAppliedWithTransactionOpen.countDown();
			await(allowResolutionCommit);
			return response;
		}).when(warrantyService).deductForAfterSale(
			eq(worker.getId()), eq(afterSale.getId()), any(BigDecimal.class),
			anyString());
		ExecutorService executor = Executors.newFixedThreadPool(2);
		Future<AfterSaleResponse> deduction = executor.submit(() ->
			afterSaleService.adminResolve(admin.getId(), afterSale.getId(),
				"售后责任扣减", new BigDecimal("10.00")));
		try {
			assertThat(deductionAppliedWithTransactionOpen
				.await(5, TimeUnit.SECONDS)).isTrue();
			Future<Object> acceptance = executor.submit(() -> {
				acceptStarted.countDown();
				try {
					return bookingsService.accept(worker.getId(), booking.id());
				} catch (Throwable error) {
					return error;
				}
			});
			assertThat(acceptStarted.await(5, TimeUnit.SECONDS)).isTrue();

			assertThatThrownBy(() -> acceptance.get(300, TimeUnit.MILLISECONDS))
				.isInstanceOf(TimeoutException.class);

			allowResolutionCommit.countDown();
			assertThat(deduction.get(5, TimeUnit.SECONDS).status())
				.isEqualTo(AfterSaleStatus.RESOLVED);
			Object result = acceptance.get(5, TimeUnit.SECONDS);
			assertThat(result).isInstanceOfSatisfying(BusinessException.class,
				error -> assertThat(error.code())
					.isEqualTo("WORKER_WARRANTY_TOP_UP_REQUIRED"));
		} finally {
			allowResolutionCommit.countDown();
			executor.shutdownNow();
		}

		assertThat(bookings.findById(booking.id())).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.PENDING);
		assertThat(warrantyAccounts.findByWorkerUserId(worker.getId())).get()
			.extracting(WorkerWarrantyAccount::getEffectiveBalance)
			.isEqualTo(new BigDecimal("90.00"));
		assertThat(warrantyContributions
			.findOutstandingByWorkerUserId(worker.getId())).singleElement()
			.satisfies(item -> assertThat(item.getAmountDue())
				.isEqualByComparingTo("10.00"));
	}

	@ParameterizedTest
	@EnumSource(CompetingTerminalAction.class)
	void acceptWaitsForConcurrentRejectOrCancelAndNeverOverwritesTerminalState(
			CompetingTerminalAction action) throws Exception {
		User owner = createUser("13800138211", UserRole.OWNER);
		User worker = createUser("13800138212", UserRole.WORKER);
		workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(), "并发师傅",
			"成都", "木工", 8, new BigDecimal("600.00"), "木作施工"));
		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(), "并发业主",
			"成都", "旧房改造", "武侯区", new BigDecimal("88.00")));
		BookingResponse booking = bookingsService.create(owner.getId(),
			new BookingRequest(worker.getId(), "木工", "成都", "武侯区",
				new BigDecimal("88.00"), (short) 3, (short) 2, (short) 1,
				(short) 2, "接单与终态并发"));
		WorkerWarrantyAccount account = WorkerWarrantyAccount.create(worker.getId());
		account.credit(new BigDecimal("100.00"));
		warrantyAccounts.saveAndFlush(account);

		CountDownLatch terminalFlowHasBookingLock = new CountDownLatch(1);
		CountDownLatch allowTerminalFlow = new CountDownLatch(1);
		CountDownLatch acceptStarted = new CountDownLatch(1);
		ExecutorService executor = Executors.newFixedThreadPool(2);
		Future<?> terminalFlow = executor.submit(() ->
			new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
				bookings.findByIdForUpdate(booking.id()).orElseThrow();
				terminalFlowHasBookingLock.countDown();
				await(allowTerminalFlow);
				if (action == CompetingTerminalAction.REJECT) {
					bookingsService.reject(worker.getId(), booking.id());
				} else {
					bookingsService.ownerCancel(owner.getId(), booking.id(), "业主取消");
				}
			}));
		try {
			assertThat(terminalFlowHasBookingLock.await(5, TimeUnit.SECONDS)).isTrue();
			Future<Object> acceptance = executor.submit(() -> {
				acceptStarted.countDown();
				try {
					return bookingsService.accept(worker.getId(), booking.id());
				} catch (Throwable error) {
					return error;
				}
			});
			assertThat(acceptStarted.await(5, TimeUnit.SECONDS)).isTrue();
			assertThatThrownBy(() -> acceptance.get(300, TimeUnit.MILLISECONDS))
				.isInstanceOf(TimeoutException.class);

			allowTerminalFlow.countDown();
			terminalFlow.get(5, TimeUnit.SECONDS);
			assertThat(acceptance.get(5, TimeUnit.SECONDS))
				.isInstanceOf(IllegalStateException.class);
		} finally {
			allowTerminalFlow.countDown();
			executor.shutdownNow();
		}

		BookingStatus expected = action == CompetingTerminalAction.REJECT
			? BookingStatus.REJECTED : BookingStatus.CANCELLED;
		assertThat(bookings.findById(booking.id())).get()
			.extracting(Booking::getStatus).isEqualTo(expected);
	}

	private enum CompetingTerminalAction {
		REJECT,
		CANCEL
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}

	private static void await(CountDownLatch latch) {
		try {
			if (!latch.await(5, TimeUnit.SECONDS)) {
				throw new AssertionError("latch timed out");
			}
		} catch (InterruptedException error) {
			Thread.currentThread().interrupt();
			throw new AssertionError(error);
		}
	}
}
