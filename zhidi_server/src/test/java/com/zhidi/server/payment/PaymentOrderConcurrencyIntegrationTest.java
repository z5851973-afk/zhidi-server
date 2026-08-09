package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.util.ReflectionTestUtils;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class PaymentOrderConcurrencyIntegrationTest extends MySqlContainerSupport {

	private static final AtomicInteger PHONE_SEQUENCE =
		new AtomicInteger(70_000_000);

	@Autowired PaymentOrderService service;
	@MockitoSpyBean PaymentOrderRepository paymentOrders;
	@MockitoSpyBean PaymentReferenceClaimRepository paymentReferenceClaims;
	@Autowired WorkerWarrantyContributionRepository warrantyContributions;
	@Autowired WorkerWarrantyLedgerEntryRepository warrantyLedger;
	@Autowired WorkerWarrantyAccountRepository warrantyAccounts;
	@Autowired BookingRepository bookings;
	@Autowired ServiceRequestRepository serviceRequests;
	@Autowired UserRepository users;
	@Autowired JwtTokenService tokens;
	@Autowired TestRestTemplate rest;
	@Autowired JdbcTemplate jdbc;
	@Autowired EntityManagerFactory entityManagerFactory;

	@BeforeEach
	void cleanDatabase() {
		if (referenceClaimTableExists()) {
			jdbc.update("DELETE FROM payment_reference_claims");
		}
		warrantyLedger.deleteAll();
		warrantyContributions.deleteAll();
		warrantyAccounts.deleteAll();
		paymentOrders.deleteAll();
		bookings.deleteAll();
		serviceRequests.deleteAll();
		users.deleteAll();
	}

	@Test
	void concurrentConstructionConfirmationAndPlatformVerificationEndPaidOnce()
			throws Exception {
		Participants participants = createParticipants();
		PaymentOrder order = createOrder(participants, "finalize");
		service.reportSplitOfflinePayments(
			participants.owner().getId(), order.getId(),
			"BANK_TRANSFER", "finalize-construction-ref",
			"CORPORATE_TRANSFER", "finalize-platform-ref", null);

		CountDownLatch ordinaryLoads = new CountDownLatch(2);
		doAnswer(invocation -> {
			PaymentOrder detached = loadDetached(order.getId());
			ordinaryLoads.countDown();
			await(ordinaryLoads);
			return Optional.of(detached);
		}).when(paymentOrders).findById(order.getId());

		List<Object> results = runConcurrently(
			() -> service.confirmConstructionReceipt(
				participants.worker().getId(), order.getId()),
			() -> service.verifyPlatformFee(
				participants.admin().getId(), order.getId(), true, null));

		assertThat(results)
			.as("concurrent finalization results: %s", results)
			.allMatch(PaymentOrderResponse.class::isInstance);
		PaymentOrder persisted = loadDetached(order.getId());
		assertThat(persisted.getStatus()).isEqualTo(PaymentOrderStatus.PAID);
		assertThat(persisted.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.CONFIRMED);
		assertThat(persisted.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.VERIFIED);
		assertThat(warrantyContributions.findByPaymentOrderId(order.getId()))
			.isPresent();
		assertThat(warrantyContributions.count()).isEqualTo(1);
	}

	@Test
	void concurrentCrossOrderComponentsCanClaimAReferenceOnlyOnce()
			throws Exception {
		Participants participants = createParticipants();
		PaymentOrder constructionOrder = createOrder(participants, "construction");
		PaymentOrder platformOrder = createOrder(participants, "platform");
		String sharedReference = "cross-component-shared-ref";

		CountDownLatch legacyChecks = new CountDownLatch(2);
		doAnswer(invocation -> {
			legacyChecks.countDown();
			await(legacyChecks);
			return false;
		}).when(paymentOrders).existsReferenceOnOtherOrder(
			eq(sharedReference), any(UUID.class));

		List<Object> results = runConcurrently(
			() -> service.reportSplitOfflinePayments(
				participants.owner().getId(), constructionOrder.getId(),
				"BANK_TRANSFER", sharedReference,
				null, null, null),
			() -> service.reportSplitOfflinePayments(
				participants.owner().getId(), platformOrder.getId(),
				null, null,
				"CORPORATE_TRANSFER", sharedReference, null));

		assertThat(results.stream()
			.filter(PaymentOrderResponse.class::isInstance)).hasSize(1);
		assertThat(results.stream()
			.filter(BusinessException.class::isInstance)
			.map(BusinessException.class::cast))
			.singleElement()
			.satisfies(error -> assertThat(error.code())
				.isEqualTo("PAYMENT_REFERENCE_ALREADY_USED"));

		PaymentOrder construction = loadDetached(constructionOrder.getId());
		PaymentOrder platform = loadDetached(platformOrder.getId());
		long storedReferences = java.util.stream.Stream.of(
			construction.getConstructionPaymentReference(),
			platform.getPlatformFeeReference())
			.filter(sharedReference::equals)
			.count();
		assertThat(storedReferences).isEqualTo(1);
		assertThat(referenceClaimCount(sharedReference)).isEqualTo(1);
	}

	@Test
	void concurrentSwappedReferencePairsHaveOneAtomicWinnerWithoutDeadlock()
			throws Exception {
		Participants participants = createParticipants();
		PaymentOrder firstOrder = createOrder(participants, "swapped-first");
		PaymentOrder secondOrder = createOrder(participants, "swapped-second");
		String firstConstructionInput = " swapped-reference-a ";
		String firstPlatformInput = "SWAPPED-REFERENCE-B";
		String secondConstructionInput = "swapped-reference-b";
		String secondPlatformInput = " SWAPPED-REFERENCE-A ";

		CountDownLatch firstClaimAttempts = new CountDownLatch(2);
		CountDownLatch distinctFirstClaimsInserted = new CountDownLatch(2);
		Map<Thread, String> firstReferenceByThread = new ConcurrentHashMap<>();
		doAnswer(invocation -> {
			PaymentReferenceClaim claim = invocation.getArgument(0);
			boolean firstClaimForThread = firstReferenceByThread.putIfAbsent(
				Thread.currentThread(), claim.getPaymentReference()) == null;
			if (firstClaimForThread) {
				firstClaimAttempts.countDown();
				await(firstClaimAttempts);
			}
			boolean distinctFirstReferences = firstReferenceByThread.values()
				.stream()
				.map(reference -> reference.toLowerCase(Locale.ROOT))
				.distinct()
				.count() == 2;
			jdbc.update("""
				INSERT INTO payment_reference_claims (
					payment_reference, payment_order_id, component, created_at
				) VALUES (?, UNHEX(REPLACE(?, '-', '')), ?, ?)
				""",
				claim.getPaymentReference(), claim.getPaymentOrderId().toString(),
				claim.getComponent().name(), Timestamp.from(claim.getCreatedAt()));
			if (firstClaimForThread && distinctFirstReferences) {
				distinctFirstClaimsInserted.countDown();
				await(distinctFirstClaimsInserted);
			}
			return claim;
		}).when(paymentReferenceClaims)
			.saveAndFlush(any(PaymentReferenceClaim.class));

		List<Object> results = runConcurrently(
			() -> service.reportSplitOfflinePayments(
				participants.owner().getId(), firstOrder.getId(),
				"BANK_TRANSFER", firstConstructionInput,
				"CORPORATE_TRANSFER", firstPlatformInput, null),
			() -> service.reportSplitOfflinePayments(
				participants.owner().getId(), secondOrder.getId(),
				"BANK_TRANSFER", secondConstructionInput,
				"CORPORATE_TRANSFER", secondPlatformInput, null));

		assertThat(results).allSatisfy(result -> assertThat(result)
			.isInstanceOfAny(PaymentOrderResponse.class, BusinessException.class));
		assertThat(results.stream()
			.filter(PaymentOrderResponse.class::isInstance)).hasSize(1);
		assertThat(results.stream()
			.filter(BusinessException.class::isInstance)
			.map(BusinessException.class::cast))
			.singleElement()
			.satisfies(error -> assertThat(error.code())
				.isEqualTo("PAYMENT_REFERENCE_ALREADY_USED"));

		PaymentOrder first = loadDetached(firstOrder.getId());
		PaymentOrder second = loadDetached(secondOrder.getId());
		boolean firstWon = hasReportedReferences(
			first, "swapped-reference-a", "SWAPPED-REFERENCE-B");
		boolean secondWon = hasReportedReferences(
			second, "swapped-reference-b", "SWAPPED-REFERENCE-A");
		assertThat(firstWon ^ secondWon).isTrue();
		PaymentOrder winner = firstWon ? first : second;
		PaymentOrder loser = firstWon ? second : first;
		assertThat(winner.getStatus()).isEqualTo(PaymentOrderStatus.UNDER_REVIEW);
		assertThat(loser.getStatus()).isEqualTo(PaymentOrderStatus.PENDING);
		assertThat(loser.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.NOT_REPORTED);
		assertThat(loser.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.NOT_REPORTED);
		assertThat(loser.getConstructionPaymentReference()).isNull();
		assertThat(loser.getPlatformFeeReference()).isNull();
		assertThat(referenceClaimCount("swapped-reference-a")).isEqualTo(1);
		assertThat(referenceClaimCount("swapped-reference-b")).isEqualTo(1);
	}

	@Test
	void httpPartialReportCannotTamperWithConfirmedConstructionReference() {
		Participants participants = createParticipants();
		PaymentOrder order = createOrder(participants, "http-tamper");
		service.reportSplitOfflinePayments(
			participants.owner().getId(), order.getId(),
			"BANK_TRANSFER", "http-original-construction-ref",
			"CORPORATE_TRANSFER", "http-rejected-platform-ref", null);
		service.confirmConstructionReceipt(
			participants.worker().getId(), order.getId());
		service.verifyPlatformFee(
			participants.admin().getId(), order.getId(), false, "流水号无法核对");

		HttpHeaders headers = new HttpHeaders();
		headers.setBearerAuth(tokens.issue(
			participants.owner().getId(), participants.owner().getPhone(),
			participants.owner().getRoles()).accessToken());
		headers.setContentType(MediaType.APPLICATION_JSON);
		ResponseEntity<String> response = rest.exchange(
			"/api/v1/payment/orders/" + order.getId() + "/offline-split-report",
			HttpMethod.POST,
			new HttpEntity<>(Map.of(
				"constructionChannel", "CASH",
				"constructionReference", "http-tampered-construction-ref",
				"platformFeeChannel", "CORPORATE_TRANSFER",
				"platformFeeReference", "http-new-platform-ref"), headers),
			String.class);

		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
		assertThat(response.getBody()).contains("\"code\":\"INVALID_STATUS\"");
		PaymentOrder persisted = loadDetached(order.getId());
		assertThat(persisted.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.CONFIRMED);
		assertThat(persisted.getConstructionPaymentReference())
			.isEqualTo("http-original-construction-ref");
		assertThat(persisted.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.REJECTED);
		assertThat(persisted.getPlatformFeeReference())
			.isEqualTo("http-rejected-platform-ref");
		assertThat(referenceClaimCount("http-new-platform-ref")).isZero();
	}

	@Test
	void httpPartialReportCannotTamperWithVerifiedPlatformReference() {
		Participants participants = createParticipants();
		PaymentOrder order = createOrder(participants, "http-platform-tamper");
		service.reportSplitOfflinePayments(
			participants.owner().getId(), order.getId(),
			"BANK_TRANSFER", "http-rejected-construction-ref",
			"CORPORATE_TRANSFER", "http-original-platform-ref", null);
		service.verifyPlatformFee(
			participants.admin().getId(), order.getId(), true, null);
		PaymentOrder rejectedConstruction = loadDetached(order.getId());
		ReflectionTestUtils.setField(rejectedConstruction,
			"constructionPaymentStatus", PaymentComponentStatus.REJECTED);
		ReflectionTestUtils.setField(rejectedConstruction,
			"status", PaymentOrderStatus.PARTIALLY_REPORTED);
		paymentOrders.saveAndFlush(rejectedConstruction);

		ResponseEntity<String> response = postSplitReport(
			participants.owner(), order.getId(), Map.of(
				"constructionChannel", "BANK_TRANSFER",
				"constructionReference", "http-new-construction-ref",
				"platformFeeChannel", "CASH",
				"platformFeeReference", "http-tampered-platform-ref"));

		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
		assertThat(response.getBody()).contains("\"code\":\"INVALID_STATUS\"");
		PaymentOrder persisted = loadDetached(order.getId());
		assertThat(persisted.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.REJECTED);
		assertThat(persisted.getConstructionPaymentReference())
			.isEqualTo("http-rejected-construction-ref");
		assertThat(persisted.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.VERIFIED);
		assertThat(persisted.getPlatformFeeReference())
			.isEqualTo("http-original-platform-ref");
		assertThat(referenceClaimCount("http-new-construction-ref")).isZero();
		assertThat(referenceClaimCount("http-tampered-platform-ref")).isZero();
	}

	@Test
	void httpLegacyFourFieldPayloadKeepsMatchingConfirmedComponentReadOnly() {
		Participants participants = createParticipants();
		PaymentOrder order = createOrder(participants, "http-legacy-fields");
		service.reportSplitOfflinePayments(
			participants.owner().getId(), order.getId(),
			"BANK_TRANSFER", "http-confirmed-construction-ref",
			"CORPORATE_TRANSFER", "http-old-platform-ref", null);
		service.confirmConstructionReceipt(
			participants.worker().getId(), order.getId());
		service.verifyPlatformFee(
			participants.admin().getId(), order.getId(), false, "流水号无法核对");

		ResponseEntity<String> response = postSplitReport(
			participants.owner(), order.getId(), Map.of(
				"constructionChannel", "BANK_TRANSFER",
				"constructionReference", "http-confirmed-construction-ref",
				"platformFeeChannel", "CORPORATE_TRANSFER",
				"platformFeeReference", "http-new-platform-legacy-ref"));

		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		PaymentOrder persisted = loadDetached(order.getId());
		assertThat(persisted.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.CONFIRMED);
		assertThat(persisted.getConstructionPaymentReference())
			.isEqualTo("http-confirmed-construction-ref");
		assertThat(persisted.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.REPORTED);
		assertThat(persisted.getPlatformFeeReference())
			.isEqualTo("http-new-platform-legacy-ref");
		assertThat(referenceClaimCount("http-new-platform-legacy-ref"))
			.isEqualTo(1);
	}

	private Participants createParticipants() {
		return new Participants(
			createUser(UserRole.OWNER),
			createUser(UserRole.WORKER),
			createUser(UserRole.ADMIN));
	}

	private User createUser(UserRole role) {
		User user = User.create("166" + String.format("%08d",
			PHONE_SEQUENCE.getAndIncrement()));
		user.grantRole(role);
		return users.saveAndFlush(user);
	}

	private PaymentOrder createOrder(Participants participants, String label) {
		ServiceRequest request = serviceRequests.saveAndFlush(ServiceRequest.create(
			participants.owner().getId(), "carpentry", "成都市",
			"支付并发测试-" + label, null));
		Booking booking = Booking.createCandidate(
			request, participants.owner().getId(), "并发测试业主",
			participants.owner().getPhone(), participants.worker().getId(),
			"并发测试师傅");
		ReflectionTestUtils.setField(booking, "status", BookingStatus.COMPLETED);
		booking = bookings.saveAndFlush(booking);
		return paymentOrders.saveAndFlush(PaymentOrder.createSplitOffline(
			booking.getId(), participants.owner().getId(),
			participants.worker().getId(), null, new BigDecimal("1000.00")));
	}

	private PaymentOrder loadDetached(UUID orderId) {
		EntityManager entityManager = entityManagerFactory.createEntityManager();
		try {
			return entityManager.find(PaymentOrder.class, orderId);
		} finally {
			entityManager.close();
		}
	}

	private ResponseEntity<String> postSplitReport(User owner, UUID orderId,
			Map<String, String> body) {
		HttpHeaders headers = new HttpHeaders();
		headers.setBearerAuth(tokens.issue(
			owner.getId(), owner.getPhone(), owner.getRoles()).accessToken());
		headers.setContentType(MediaType.APPLICATION_JSON);
		return rest.exchange(
			"/api/v1/payment/orders/" + orderId + "/offline-split-report",
			HttpMethod.POST, new HttpEntity<>(body, headers), String.class);
	}

	private List<Object> runConcurrently(Callable<?> firstAction,
			Callable<?> secondAction) throws Exception {
		ExecutorService executor = Executors.newFixedThreadPool(2);
		CountDownLatch ready = new CountDownLatch(2);
		CountDownLatch start = new CountDownLatch(1);
		try {
			Future<Object> first = executor.submit(
				() -> runAfter(ready, start, firstAction));
			Future<Object> second = executor.submit(
				() -> runAfter(ready, start, secondAction));
			assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
			start.countDown();
			return List.of(
				first.get(10, TimeUnit.SECONDS),
				second.get(10, TimeUnit.SECONDS));
		} finally {
			start.countDown();
			executor.shutdownNow();
		}
	}

	private static Object runAfter(CountDownLatch ready, CountDownLatch start,
			Callable<?> action) {
		ready.countDown();
		try {
			if (!start.await(5, TimeUnit.SECONDS)) {
				return new AssertionError("concurrent start timed out");
			}
			return action.call();
		} catch (Throwable error) {
			return error;
		}
	}

	private static void await(CountDownLatch latch) {
		try {
			if (!latch.await(5, TimeUnit.SECONDS)) {
				throw new AssertionError("concurrency latch timed out");
			}
		} catch (InterruptedException error) {
			Thread.currentThread().interrupt();
			throw new AssertionError(error);
		}
	}

	private boolean referenceClaimTableExists() {
		Integer count = jdbc.queryForObject("""
			SELECT COUNT(*) FROM information_schema.tables
			WHERE table_schema = DATABASE()
			  AND table_name = 'payment_reference_claims'
			""", Integer.class);
		return count != null && count == 1;
	}

	private int referenceClaimCount(String reference) {
		Integer count = jdbc.queryForObject("""
			SELECT COUNT(*) FROM payment_reference_claims
			WHERE payment_reference = ?
			""", Integer.class, reference);
		return count == null ? 0 : count;
	}

	private static boolean hasReportedReferences(PaymentOrder order,
			String constructionReference, String platformReference) {
		return order.getConstructionPaymentStatus()
				== PaymentComponentStatus.REPORTED
			&& order.getPlatformFeeStatus() == PaymentComponentStatus.REPORTED
			&& constructionReference.equals(
				order.getConstructionPaymentReference())
			&& platformReference.equals(order.getPlatformFeeReference());
	}

	private record Participants(User owner, User worker, User admin) {}
}
