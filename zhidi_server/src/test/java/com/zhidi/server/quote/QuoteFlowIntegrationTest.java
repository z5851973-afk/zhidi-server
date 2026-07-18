package com.zhidi.server.quote;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingService;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.booking.VisitProposalRepository;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.servicerequest.ServiceRequestStatus;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class QuoteFlowIntegrationTest extends MySqlContainerSupport {

	@Autowired
	QuoteService quoteService;

	@Autowired
	BookingService bookingService;

	@Autowired
	QuoteRepository quotes;

	@Autowired
	BookingRepository bookings;

	@Autowired
	ServiceCatalogRepository catalogs;

	@Autowired
	ServiceRequestRepository serviceRequests;

	@Autowired
	UserRepository users;

	@Autowired
	WorkerProfileRepository workerProfiles;

	@Autowired
	OwnerProfileRepository ownerProfiles;

	@Autowired
	VisitProposalRepository visitProposals;

	private User owner;
	private User worker;

	@BeforeEach
	void cleanDatabase() {
		quotes.deleteAll();
		visitProposals.deleteAll();
		bookings.deleteAll();
		serviceRequests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();

		owner = createUser("13800138201", UserRole.OWNER);
		worker = createUser("13800138202", UserRole.WORKER);

		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(),
			"张业主", "杭州", "新房装修", "余杭区", new BigDecimal("120.00")));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(),
			"李师傅", "杭州", "木工", 8, new BigDecimal("500.00"), "木工经验丰富"));

		catalogs.deleteAll();
		catalogs.saveAllAndFlush(List.of(
			new ServiceCatalog("CARPENTRY", "门套安装", "套",
				new BigDecimal("200.00"), false, 1),
			new ServiceCatalog("CARPENTRY", "踢脚线安装", "米",
				new BigDecimal("35.00"), false, 2),
			new ServiceCatalog("CARPENTRY", "吊顶安装", "平米",
				new BigDecimal("120.00"), false, 3),
			new ServiceCatalog("CARPENTRY", "柜体安装", "平米",
				new BigDecimal("300.00"), false, 4)
		));
	}

	@Test
	void submitQuoteFromOnSiteSucceeds() {
		UUID bookingId = createOnSiteBooking();

		QuoteRequest request = new QuoteRequest(List.of(
			new QuoteItemRequest("门套安装", new BigDecimal("3"), null),
			new QuoteItemRequest("踢脚线安装", new BigDecimal("20"), null)
		));
		QuoteResponse response = quoteService.submit(
			worker.getId(), bookingId, request);

		assertThat(response.status()).isEqualTo(QuoteStatus.SUBMITTED);
		assertThat(response.items()).hasSize(2);
		QuoteItem item1 = response.items().get(0);
		assertThat(item1.name()).isEqualTo("门套安装");
		assertThat(item1.quantity()).isEqualByComparingTo("3");
		assertThat(item1.unitPrice()).isEqualByComparingTo("200.00");
		assertThat(item1.subtotal()).isEqualByComparingTo("600.00");
		assertThat(item1.snapshotCatalogId()).isNotNull();

		// Booking status should be QUOTE_PENDING
		Booking booking = bookings.findById(bookingId).orElseThrow();
		assertThat(booking.getStatus()).isEqualTo(BookingStatus.QUOTE_PENDING);
	}

	@Test
	void submitQuoteWithMatchingUnitPriceSucceeds() {
		UUID bookingId = createOnSiteBooking();

		QuoteRequest request = new QuoteRequest(List.of(
			new QuoteItemRequest("门套安装", new BigDecimal("2"),
				new BigDecimal("200.00"))
		));
		QuoteResponse response = quoteService.submit(
			worker.getId(), bookingId, request);

		assertThat(response.status()).isEqualTo(QuoteStatus.SUBMITTED);
		assertThat(response.items().get(0).unitPrice())
			.isEqualByComparingTo("200.00");
	}

	@Test
	void submitQuoteWithWrongUnitPriceFails() {
		UUID bookingId = createOnSiteBooking();

		QuoteRequest request = new QuoteRequest(List.of(
			new QuoteItemRequest("门套安装", new BigDecimal("1"),
				new BigDecimal("150.00"))
		));
		Throwable error = catchThrowable(() ->
			quoteService.submit(worker.getId(), bookingId, request));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("PRICE_MISMATCH");
		});
	}

	@Test
	void submitQuoteWithUnknownItemFails() {
		UUID bookingId = createOnSiteBooking();

		QuoteRequest request = new QuoteRequest(List.of(
			new QuoteItemRequest("不存在的项目", new BigDecimal("1"), null)
		));
		Throwable error = catchThrowable(() ->
			quoteService.submit(worker.getId(), bookingId, request));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("ITEM_NOT_IN_CATALOG");
		});
	}

	@Test
	void submitQuoteNotOnSiteFails() {
		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "测试")).getId();

		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker.getId(), "李师傅"));
		booking.accept();
		bookings.saveAndFlush(booking);

		QuoteRequest request = new QuoteRequest(List.of(
			new QuoteItemRequest("门套安装", new BigDecimal("1"), null)
		));
		Throwable error = catchThrowable(() ->
			quoteService.submit(worker.getId(), booking.getId(), request));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(409);
			assertThat(ex.code()).isEqualTo("INVALID_STATUS");
		});
	}

	@Test
	void getCatalogReturnsCorrectItems() {
		List<ServiceCatalogResponse> items = quoteService.getCatalog("木工");

		assertThat(items).hasSize(4);
		assertThat(items.get(0).name()).isEqualTo("门套安装");
		assertThat(items.get(0).unitPrice()).isEqualByComparingTo("200.00");
	}

	@Test
	void getCatalogWithStandardCategory() {
		List<ServiceCatalogResponse> items = quoteService.getCatalog("CARPENTRY");

		assertThat(items).hasSize(4);
	}

	@Test
	void getCatalogEmptyCategoryFails() {
		Throwable error = catchThrowable(() -> quoteService.getCatalog(""));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("CATEGORY_REQUIRED");
		});
	}

	@Test
	void listForBookingReturnsSnapshotPrices() {
		UUID bookingId = createOnSiteBooking();

		quoteService.submit(worker.getId(), bookingId, new QuoteRequest(List.of(
			new QuoteItemRequest("门套安装", new BigDecimal("2"), null)
		)));

		List<QuoteResponse> quotes = quoteService.listForBooking(bookingId);
		assertThat(quotes).hasSize(1);
		QuoteItem item = quotes.get(0).items().get(0);
		assertThat(item.unitPrice()).isEqualByComparingTo("200.00");
		assertThat(item.subtotal()).isEqualByComparingTo("400.00");
		assertThat(item.snapshotCatalogId()).isNotNull();
	}

	@Test
	void resolveCategoriesTrades() {
		assertThat(QuoteService.resolveCategories("木工"))
			.containsExactly("CARPENTRY");
		assertThat(QuoteService.resolveCategories("水电动"))
			.containsExactlyInAnyOrder("PLUMBING", "ELECTRICAL");
		assertThat(QuoteService.resolveCategories("水电"))
			.containsExactlyInAnyOrder("PLUMBING", "ELECTRICAL");
		assertThat(QuoteService.resolveCategories("泥瓦"))
			.containsExactly("MASONRY");
		assertThat(QuoteService.resolveCategories("泥工"))
			.containsExactly("MASONRY");
		assertThat(QuoteService.resolveCategories("油漆"))
			.containsExactly("PAINTING");
		assertThat(QuoteService.resolveCategories("拆除"))
			.containsExactly("DEMOLITION");
		assertThat(QuoteService.resolveCategories("CARPENTRY"))
			.containsExactly("CARPENTRY");
	}

	// ──────── 阶段 4：接受/拒绝报价 ————————

	@Test
	void acceptQuoteSucceedsAndClosesOtherCandidates() {
		// Arrange: create two candidates on the same ServiceRequest,
		// both with submitted quotes
		ServiceRequest sr = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "多人比价测试"));

		// Worker 1 (instance field `worker`) — the one we'll select
		UUID bookingId1 = createOnSiteBookingForRequest(sr.getId());
		QuoteResponse q1 = quoteService.submit(worker.getId(), bookingId1,
			new QuoteRequest(List.of(
				new QuoteItemRequest("门套安装", new BigDecimal("2"), null))));

		// Worker 2 — competing candidate
		User worker2 = createUser("13800138302", UserRole.WORKER);
		workerProfiles.saveAndFlush(WorkerProfile.create(worker2.getId(),
			"王师傅", "杭州", "木工", 5, new BigDecimal("400.00"), "精细木工"));

		Booking booking2 = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(sr.getId()).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker2.getId(), "王师傅"));
		booking2.accept();
		bookings.saveAndFlush(booking2);

		// Set worker2 ON_SITE and submit quote
		setOnSite(booking2.getId(), worker2.getId());
		quoteService.submit(worker2.getId(), booking2.getId(),
			new QuoteRequest(List.of(
				new QuoteItemRequest("踢脚线安装", new BigDecimal("10"), null))));

		// Act: owner accepts worker1's quote
		QuoteResponse result = quoteService.acceptQuote(owner.getId(), q1.id());

		// Assert
		assertThat(result.status()).isEqualTo(QuoteStatus.ACCEPTED);

		// Target booking → HIRED
		Booking hiredBooking = bookings.findById(bookingId1).orElseThrow();
		assertThat(hiredBooking.getStatus()).isEqualTo(BookingStatus.HIRED);

		// Other booking → NOT_SELECTED
		Booking otherBooking = bookings.findById(booking2.getId()).orElseThrow();
		assertThat(otherBooking.getStatus()).isEqualTo(BookingStatus.NOT_SELECTED);

		// Other worker's quote → REJECTED
		List<Quote> otherQuotes = quotes
			.findByBookingIdOrderByCreatedAtDesc(booking2.getId());
		assertThat(otherQuotes).allMatch(
			q -> q.getStatus() == QuoteStatus.REJECTED);

		// ServiceRequest → ASSIGNED
		ServiceRequest updatedSr = serviceRequests.findById(sr.getId())
			.orElseThrow();
		assertThat(updatedSr.getStatus()).isEqualTo(
			ServiceRequestStatus.ASSIGNED);
	}

	@Test
	void acceptQuoteWrongOwnerFails() {
		UUID bookingId = createOnSiteBooking();
		QuoteResponse quote = quoteService.submit(worker.getId(), bookingId,
			new QuoteRequest(List.of(
				new QuoteItemRequest("门套安装", new BigDecimal("1"), null))));

		User otherOwner = createUser("13800138303", UserRole.OWNER);
		ownerProfiles.saveAndFlush(OwnerProfile.create(otherOwner.getId(),
			"李业主", "杭州", "新房", "滨江区", new BigDecimal("100.00")));

		Throwable error = catchThrowable(() ->
			quoteService.acceptQuote(otherOwner.getId(), quote.id()));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(403);
			assertThat(ex.code()).isEqualTo("NOT_OWNER");
		});
	}

	@Test
	void acceptQuoteAlreadyAcceptedFails() {
		UUID bookingId = createOnSiteBooking();
		QuoteResponse quote = quoteService.submit(worker.getId(), bookingId,
			new QuoteRequest(List.of(
				new QuoteItemRequest("门套安装", new BigDecimal("1"), null))));

		quoteService.acceptQuote(owner.getId(), quote.id());

		Throwable error = catchThrowable(() ->
			quoteService.acceptQuote(owner.getId(), quote.id()));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(409);
			assertThat(ex.code()).isEqualTo("INVALID_QUOTE_STATUS");
		});
	}

	@Test
	void rejectQuoteSucceedsAndAllowsRepropose() {
		UUID bookingId = createOnSiteBooking();
		QuoteResponse quote = quoteService.submit(worker.getId(), bookingId,
			new QuoteRequest(List.of(
				new QuoteItemRequest("门套安装", new BigDecimal("1"), null))));

		QuoteResponse result = quoteService.rejectQuote(owner.getId(),
			quote.id(), "价格太高，请重新报价");

		assertThat(result.status()).isEqualTo(QuoteStatus.REJECTED);
		assertThat(result.rejectReason()).isEqualTo("价格太高，请重新报价");

		// Booking → ON_SITE (worker can re-submit)
		Booking booking = bookings.findById(bookingId).orElseThrow();
		assertThat(booking.getStatus()).isEqualTo(BookingStatus.ON_SITE);

		// Worker can re-submit a new quote
		QuoteResponse q2 = quoteService.submit(worker.getId(), bookingId,
			new QuoteRequest(List.of(
				new QuoteItemRequest("踢脚线安装", new BigDecimal("10"), null))));
		assertThat(q2.status()).isEqualTo(QuoteStatus.SUBMITTED);
	}

	@Test
	void rejectQuoteWithoutReasonFails() {
		UUID bookingId = createOnSiteBooking();
		QuoteResponse quote = quoteService.submit(worker.getId(), bookingId,
			new QuoteRequest(List.of(
				new QuoteItemRequest("门套安装", new BigDecimal("1"), null))));

		Throwable error = catchThrowable(() ->
			quoteService.rejectQuote(owner.getId(), quote.id(), "  "));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("REASON_REQUIRED");
		});

		error = catchThrowable(() ->
			quoteService.rejectQuote(owner.getId(), quote.id(), null));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("REASON_REQUIRED");
		});
	}

	@Test
	void rejectQuoteWrongOwnerFails() {
		UUID bookingId = createOnSiteBooking();
		QuoteResponse quote = quoteService.submit(worker.getId(), bookingId,
			new QuoteRequest(List.of(
				new QuoteItemRequest("门套安装", new BigDecimal("1"), null))));

		User otherOwner = createUser("13800138304", UserRole.OWNER);
		ownerProfiles.saveAndFlush(OwnerProfile.create(otherOwner.getId(),
			"赵业主", "杭州", "新房", "拱墅区", new BigDecimal("90.00")));

		Throwable error = catchThrowable(() ->
			quoteService.rejectQuote(otherOwner.getId(), quote.id(),
				"价格太贵"));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(403);
			assertThat(ex.code()).isEqualTo("NOT_OWNER");
		});
	}

	@Test
	void listQuotesForServiceRequestSortedByPrice() {
		// Create service request with two workers
		ServiceRequest sr = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "比价测试"));

		// Worker 1 with expensive quote
		UUID bookingId1 = createOnSiteBookingForRequest(sr.getId());
		quoteService.submit(worker.getId(), bookingId1,
			new QuoteRequest(List.of(
				new QuoteItemRequest("吊顶安装", new BigDecimal("50"), null))));

		// Worker 2 with cheap quote
		User worker2 = createUser("13800138305", UserRole.WORKER);
		workerProfiles.saveAndFlush(WorkerProfile.create(worker2.getId(),
			"陈师傅", "杭州", "木工", 3, new BigDecimal("350.00"), "预算木工"));

		Booking booking2 = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(sr.getId()).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker2.getId(), "陈师傅"));
		booking2.accept();
		bookings.saveAndFlush(booking2);
		setOnSite(booking2.getId(), worker2.getId());
		quoteService.submit(worker2.getId(), booking2.getId(),
			new QuoteRequest(List.of(
				new QuoteItemRequest("门套安装", new BigDecimal("1"), null))));

		List<QuoteResponse> quotes = quoteService
			.listQuotesForServiceRequest(sr.getId());

		assertThat(quotes).hasSize(2);
		// Cheapest first (门套安装 1×200 = 200 < 吊顶安装 50×120 = 6000)
		assertThat(quotes.get(0).workerUserId()).isEqualTo(worker2.getId());
		assertThat(quotes.get(1).workerUserId()).isEqualTo(worker.getId());
	}

	// ── helpers ──

	private UUID createOnSiteBookingForRequest(UUID requestId) {
		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker.getId(), "李师傅"));
		booking.accept();
		bookings.saveAndFlush(booking);
		setOnSite(booking.getId(), worker.getId());
		return booking.getId();
	}

	private void setOnSite(UUID bookingId, UUID workerUserId) {
		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS)
			.truncatedTo(ChronoUnit.MINUTES);
		bookingService.proposeVisit(workerUserId, bookingId, proposedTime);
		bookingService.acceptVisit(owner.getId(), bookingId);
		bookingService.arrive(workerUserId, bookingId, true);
		bookingService.arrive(owner.getId(), bookingId, false);
	}

	private UUID createOnSiteBooking() {
		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "测试木工")).getId();

		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker.getId(), "李师傅"));
		booking.accept();
		bookings.saveAndFlush(booking);
		setOnSite(booking.getId(), worker.getId());
		return booking.getId();
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
