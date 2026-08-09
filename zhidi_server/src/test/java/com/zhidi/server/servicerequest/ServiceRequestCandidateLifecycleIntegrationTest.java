package com.zhidi.server.servicerequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.stream.Stream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class ServiceRequestCandidateLifecycleIntegrationTest extends MySqlContainerSupport {

	@Autowired
	ServiceRequestService service;

	@Autowired
	ServiceRequestRepository requests;

	@Autowired
	BookingRepository bookings;

	@Autowired
	UserRepository users;

	@Autowired
	WorkerProfileRepository workerProfiles;

	@Autowired
	OwnerProfileRepository ownerProfiles;

	private final List<User> workers = new ArrayList<>();
	private ExecutorService executor;
	private User owner;
	private User otherTradeWorker;

	@BeforeEach
	void setUp() {
		bookings.deleteAll();
		requests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();

		owner = createUser("13800139001", UserRole.OWNER);
		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(), "林业主",
			"成都", "旧房改造", "高新区 1 号", new BigDecimal("88.00")));
		for (int i = 0; i < 6; i++) {
			User worker = createUser("1381013900" + (i + 1), UserRole.WORKER);
			workers.add(worker);
			workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(),
				"水电师傅" + (i + 1), "成都", "水电", 5 + i,
				new BigDecimal("500.00"), "水电施工"));
		}
		otherTradeWorker = createUser("13810139999", UserRole.WORKER);
		workerProfiles.saveAndFlush(WorkerProfile.create(otherTradeWorker.getId(),
			"木工师傅", "成都", "木工", 8,
			new BigDecimal("600.00"), "木作施工"));
		executor = Executors.newFixedThreadPool(2);
	}

	@AfterEach
	void tearDown() {
		executor.shutdownNow();
	}

	@Test
	void ownerCanRemoveEveryPreOnSiteCandidateAndFreeItsSlot() {
		for (BookingStatus status : List.of(
			BookingStatus.PENDING,
			BookingStatus.ACCEPTED,
			BookingStatus.VISIT_PROPOSED,
			BookingStatus.VISIT_SCHEDULED,
			BookingStatus.ARRIVAL_PENDING)) {
			ServiceRequestResponse created = createRequest();
			ServiceRequestResponse withCandidate = service.addCandidate(owner.getId(),
				created.id(), new CandidateCreateRequest(workers.get(0).getId()));
			Booking booking = bookings.findById(withCandidate.candidates().get(0).id())
				.orElseThrow();
			advanceTo(booking, status);
			bookings.saveAndFlush(booking);

			ServiceRequestResponse removed = service.removeCandidate(owner.getId(),
				created.id(), booking.getId());

			assertThat(bookings.findById(booking.getId())).get()
				.extracting(Booking::getStatus).isEqualTo(BookingStatus.CANCELLED);
			assertThat(removed.status()).isEqualTo(ServiceRequestStatus.OPEN);
			assertThat(removed.activeCandidateCount()).isZero();
			assertThat(removed.availableCandidateSlots()).isEqualTo(3);
			assertThat(removed.canAddCandidates()).isTrue();
		}
	}

	@Test
	void onSiteAndLaterCandidatesCannotBeRemovedOrReplaced() {
		for (BookingStatus status : List.of(
			BookingStatus.ON_SITE,
			BookingStatus.HIRED,
			BookingStatus.COMPLETED)) {
			ServiceRequestResponse created = createRequest();
			ServiceRequestResponse withCandidate = service.addCandidate(owner.getId(),
				created.id(), new CandidateCreateRequest(workers.get(0).getId()));
			Booking booking = bookings.findById(withCandidate.candidates().get(0).id())
				.orElseThrow();
			advanceTo(booking, status);
			bookings.saveAndFlush(booking);

			Throwable removeError = catchThrowable(() -> service.removeCandidate(
				owner.getId(), created.id(), booking.getId()));
			Throwable replaceError = catchThrowable(() -> service.replaceCandidate(
				owner.getId(), created.id(), booking.getId(),
				new CandidateCreateRequest(workers.get(1).getId())));

			assertBusinessCode(removeError, "CANDIDATE_CANNOT_REMOVE");
			assertBusinessCode(replaceError, "CANDIDATE_CANNOT_REPLACE");
			assertThat(bookings.findById(booking.getId())).get()
				.extracting(Booking::getStatus).isEqualTo(status);
		}
	}

	@Test
	void replacementEndsOldCandidateAndCreatesOneNewActiveCandidate() {
		ServiceRequestResponse created = createRequest();
		ServiceRequestResponse withCandidate = service.addCandidate(owner.getId(),
			created.id(), new CandidateCreateRequest(workers.get(0).getId()));
		UUID oldBookingId = withCandidate.candidates().get(0).id();

		ServiceRequestResponse replaced = service.replaceCandidate(owner.getId(),
			created.id(), oldBookingId,
			new CandidateCreateRequest(workers.get(1).getId()));

		assertThat(bookings.findById(oldBookingId)).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.CANCELLED);
		assertThat(replaced.candidates()).hasSize(2);
		assertThat(replaced.candidates()).filteredOn(candidate ->
			candidate.workerUserId().equals(workers.get(1).getId()))
			.singleElement().satisfies(candidate -> {
				assertThat(candidate.status()).isEqualTo(BookingStatus.PENDING);
				assertThat(candidate.canRemove()).isTrue();
				assertThat(candidate.canReplace()).isTrue();
			});
		assertThat(replaced.activeCandidateCount()).isEqualTo(1);
		assertThat(replaced.availableCandidateSlots()).isEqualTo(2);
	}

	@Test
	void invalidReplacementRollsBackWithoutChangingOldCandidate() {
		ServiceRequestResponse created = createRequest();
		ServiceRequestResponse withCandidate = service.addCandidate(owner.getId(),
			created.id(), new CandidateCreateRequest(workers.get(0).getId()));
		UUID oldBookingId = withCandidate.candidates().get(0).id();

		Throwable error = catchThrowable(() -> service.replaceCandidate(owner.getId(),
			created.id(), oldBookingId,
			new CandidateCreateRequest(otherTradeWorker.getId())));

		assertBusinessCode(error, "WORKER_TRADE_MISMATCH");
		assertThat(bookings.findById(oldBookingId)).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.PENDING);
		assertThat(bookings.findByServiceRequestIdOrderByCreatedAtAsc(created.id()))
			.hasSize(1);
	}

	@Test
	void assignedAndCancelledRequestsRejectCandidateMutation() {
		for (ServiceRequestStatus status : List.of(
			ServiceRequestStatus.ASSIGNED,
			ServiceRequestStatus.CANCELLED)) {
			ServiceRequestResponse created = createRequest();
			ServiceRequestResponse withCandidate = service.addCandidate(owner.getId(),
				created.id(), new CandidateCreateRequest(workers.get(0).getId()));
			ServiceRequest request = requests.findById(created.id()).orElseThrow();
			if (status == ServiceRequestStatus.ASSIGNED) {
				request.markAssigned();
			} else {
				request.cancel();
			}
			requests.saveAndFlush(request);

			Throwable addError = catchThrowable(() -> service.addCandidate(owner.getId(),
				created.id(), new CandidateCreateRequest(workers.get(1).getId())));
			Throwable replaceError = catchThrowable(() -> service.replaceCandidate(
				owner.getId(), created.id(), withCandidate.candidates().get(0).id(),
				new CandidateCreateRequest(workers.get(1).getId())));

			assertBusinessCode(addError, "SERVICE_REQUEST_NOT_OPEN");
			assertBusinessCode(replaceError, "SERVICE_REQUEST_NOT_OPEN");
		}
	}

	@Test
	void concurrentAddAndReplaceNeverExceedThreeActiveCandidates() throws Exception {
		ServiceRequestResponse created = createRequest();
		for (int i = 0; i < 3; i++) {
			service.addCandidate(owner.getId(), created.id(),
				new CandidateCreateRequest(workers.get(i).getId()));
		}
		UUID oldBookingId = bookings.findByServiceRequestIdOrderByCreatedAtAsc(created.id())
			.get(0).getId();
		CountDownLatch start = new CountDownLatch(1);

		Future<Throwable> add = executor.submit(() -> runAfter(start, () ->
			service.addCandidate(owner.getId(), created.id(),
				new CandidateCreateRequest(workers.get(3).getId()))));
		Future<Throwable> replace = executor.submit(() -> runAfter(start, () ->
			service.replaceCandidate(owner.getId(), created.id(), oldBookingId,
				new CandidateCreateRequest(workers.get(4).getId()))));
		start.countDown();

		Throwable addResult = add.get();
		Throwable replaceResult = replace.get();

		List<Throwable> failures = Stream.of(addResult, replaceResult)
			.filter(java.util.Objects::nonNull).toList();
		assertThat(Stream.of(addResult, replaceResult).filter(e -> e == null)).hasSize(1);
		assertThat(failures).singleElement()
			.satisfies(error -> assertBusinessCode(error, "CANDIDATE_LIMIT_REACHED"));
		assertThat(bookings.countActiveCandidates(created.id(),
			BookingStatus.CANDIDATE_TERMINAL_STATUSES)).isLessThanOrEqualTo(3);
	}

	@Test
	void reopenClonesCancelledRequestAndPreservesOldAuditTrail() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号",
				new BigDecimal("98.50"), (short) 3, (short) 2, (short) 1,
				(short) 2, "保留原备注"));
		ServiceRequestResponse withCandidate = service.addCandidate(owner.getId(),
			created.id(), new CandidateCreateRequest(workers.get(0).getId()));
		UUID oldBookingId = withCandidate.candidates().get(0).id();
		service.cancelRequest(owner.getId(), created.id());

		ServiceRequestResponse reopened = service.reopenRequest(owner.getId(),
			created.id());

		assertThat(reopened.id()).isNotEqualTo(created.id());
		assertThat(reopened.trade()).isEqualTo(created.trade());
		assertThat(reopened.serviceCity()).isEqualTo(created.serviceCity());
		assertThat(reopened.serviceAddress()).isEqualTo(created.serviceAddress());
		assertThat(reopened.remark()).isEqualTo("保留原备注");
		assertThat(reopened.status()).isEqualTo(ServiceRequestStatus.OPEN);
		assertThat(reopened.candidates()).isEmpty();
		assertThat(reopened.activeCandidateCount()).isZero();
		assertThat(reopened.availableCandidateSlots()).isEqualTo(3);
		assertThat(reopened.canAddCandidates()).isTrue();
		assertThat(requests.findById(created.id())).get()
			.extracting(ServiceRequest::getStatus)
			.isEqualTo(ServiceRequestStatus.CANCELLED);
		assertThat(bookings.findById(oldBookingId)).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.CANCELLED);
	}

	@Test
	void nonCancelledRequestCannotBeReopened() {
		ServiceRequestResponse created = createRequest();

		Throwable error = catchThrowable(() ->
			service.reopenRequest(owner.getId(), created.id()));

		assertBusinessCode(error, "SERVICE_REQUEST_CANNOT_REOPEN");
	}

	private ServiceRequestResponse createRequest() {
		return service.createRequest(owner.getId(),
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号",
				new BigDecimal("98.50"), (short) 3, (short) 2, (short) 1,
				(short) 2, null));
	}

	private void advanceTo(Booking booking, BookingStatus target) {
		if (target == BookingStatus.PENDING) return;
		booking.accept();
		if (target == BookingStatus.ACCEPTED) return;
		booking.proposeVisit();
		if (target == BookingStatus.VISIT_PROPOSED) return;
		booking.scheduleVisit(Instant.parse("2026-08-08T10:00:00Z"));
		if (target == BookingStatus.VISIT_SCHEDULED) return;
		booking.confirmArrivalByOwner();
		if (target == BookingStatus.ARRIVAL_PENDING) return;
		booking.confirmArrivalByWorker();
		if (target == BookingStatus.ON_SITE) return;
		booking.submitQuote();
		booking.hire();
		if (target == BookingStatus.HIRED) return;
		booking.markCompleted();
	}

	private Throwable runAfter(CountDownLatch start, Runnable action) {
		try {
			start.await();
			action.run();
			return null;
		} catch (Throwable error) {
			return error;
		}
	}

	private void assertBusinessCode(Throwable error, String code) {
		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> assertThat(ex.code()).isEqualTo(code));
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
