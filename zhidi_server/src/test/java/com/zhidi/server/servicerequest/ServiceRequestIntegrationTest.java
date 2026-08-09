package com.zhidi.server.servicerequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingService;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.booking.VisitProposalRepository;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import jakarta.persistence.EntityManagerFactory;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class ServiceRequestIntegrationTest extends MySqlContainerSupport {

	@Autowired
	ServiceRequestService service;

	@Autowired
	BookingService bookingService;

	@Autowired
	ServiceRequestRepository requests;

	@Autowired
	BookingRepository bookings;

	@Autowired
	VisitProposalRepository visitProposals;

	@Autowired
	UserRepository users;

	@Autowired
	WorkerProfileRepository workerProfiles;

	@Autowired
	OwnerProfileRepository ownerProfiles;

	@Autowired
	EntityManagerFactory entityManagerFactory;

	private User owner;
	private User workerA;
	private User workerB;

	@BeforeEach
	void cleanDatabase() {
		visitProposals.deleteAll();
		bookings.deleteAll();
		requests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();
		owner = createUser("13800138101", UserRole.OWNER);
		workerA = createUser("13800138102", UserRole.WORKER);
		workerB = createUser("13800138103", UserRole.WORKER);
		workerProfiles.saveAndFlush(WorkerProfile.create(workerA.getId(), "张师傅",
			"成都", "水电", 8, new BigDecimal("580.00"), "水电改造"));
		workerProfiles.saveAndFlush(WorkerProfile.create(workerB.getId(), "王师傅",
			"成都", "水电", 6, new BigDecimal("520.00"), "新房水电"));
		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(), "林业主",
			"成都", "旧房改造", "高新区 1 号", new BigDecimal("88.00")));
	}

	@Test
	void ownerServiceRequestListIncludesPendingVisitProposalTime() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			houseRequest("旧房水电改造"));
		service.addCandidate(owner.getId(), created.id(),
			new CandidateCreateRequest(workerA.getId()));
		Booking booking = bookings.findByServiceRequestIdOrderByCreatedAtAsc(created.id())
			.get(0);
		booking.accept();
		bookings.saveAndFlush(booking);
		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS)
			.truncatedTo(ChronoUnit.MINUTES);

		bookingService.proposeVisit(workerA.getId(), booking.getId(), proposedTime);

		ServiceRequestResponse reloaded = service.listOwnerRequests(owner.getId()).get(0);
		assertThat(reloaded.candidates()).singleElement()
			.extracting(bookingResponse -> bookingResponse.proposedTime())
			.isEqualTo(proposedTime);
	}

	@Test
	void serviceRequestCandidatesAndReopenKeepTheSameStructuredHouseInfo() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号",
				new BigDecimal("98.50"), (short) 3, (short) 2, (short) 1,
				(short) 2, "只保留原备注"));
		ServiceRequestResponse withCandidate = service.addCandidate(owner.getId(),
			created.id(), new CandidateCreateRequest(workerA.getId()));

		assertThat(withCandidate.areaSqm()).isEqualByComparingTo("98.50");
		assertThat(withCandidate.bedroomCount()).isEqualTo((short) 3);
		assertThat(withCandidate.livingRoomCount()).isEqualTo((short) 2);
		assertThat(withCandidate.kitchenCount()).isEqualTo((short) 1);
		assertThat(withCandidate.bathroomCount()).isEqualTo((short) 2);
		assertThat(withCandidate.remark()).isEqualTo("只保留原备注");
		assertThat(withCandidate.candidates()).singleElement().satisfies(candidate -> {
			assertThat(candidate.areaSqm()).isEqualByComparingTo("98.50");
			assertThat(candidate.bedroomCount()).isEqualTo((short) 3);
			assertThat(candidate.livingRoomCount()).isEqualTo((short) 2);
			assertThat(candidate.kitchenCount()).isEqualTo((short) 1);
			assertThat(candidate.bathroomCount()).isEqualTo((short) 2);
		});

		service.cancelRequest(owner.getId(), created.id());
		ServiceRequestResponse reopened = service.reopenRequest(owner.getId(), created.id());

		assertThat(reopened.areaSqm()).isEqualByComparingTo("98.50");
		assertThat(reopened.bedroomCount()).isEqualTo((short) 3);
		assertThat(reopened.livingRoomCount()).isEqualTo((short) 2);
		assertThat(reopened.kitchenCount()).isEqualTo((short) 1);
		assertThat(reopened.bathroomCount()).isEqualTo((short) 2);
		assertThat(reopened.remark()).isEqualTo("只保留原备注");
	}

	@Test
	void retryingReopenReturnsTheSameSuccessorWithoutCloningAgain() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			houseRequest("旧房水电改造"));
		service.cancelRequest(owner.getId(), created.id());

		ServiceRequestResponse first = service.reopenRequest(owner.getId(), created.id());
		ServiceRequestResponse retry = service.reopenRequest(owner.getId(), created.id());

		assertThat(retry.id()).isEqualTo(first.id());
		assertThat(requests.count()).isEqualTo(2);
	}

	@Test
	void concurrentReopenCreatesOneAuditableSuccessor() throws Exception {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			houseRequest("旧房水电改造"));
		service.cancelRequest(owner.getId(), created.id());
		CountDownLatch ready = new CountDownLatch(2);
		CountDownLatch start = new CountDownLatch(1);
		ExecutorService executor = Executors.newFixedThreadPool(2);
		try {
			Future<ServiceRequestResponse> first = executor.submit(() -> {
				ready.countDown();
				start.await();
				return service.reopenRequest(owner.getId(), created.id());
			});
			Future<ServiceRequestResponse> retry = executor.submit(() -> {
				ready.countDown();
				start.await();
				return service.reopenRequest(owner.getId(), created.id());
			});
			ready.await();
			start.countDown();

			assertThat(retry.get().id()).isEqualTo(first.get().id());
		} finally {
			executor.shutdownNow();
		}
		assertThat(requests.count()).isEqualTo(2);
	}

	@Test
	void ownerRequestListLoadsCandidatesAndVisitProposalsInFixedQueryCount() {
		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS)
			.truncatedTo(ChronoUnit.MINUTES);
		for (int i = 0; i < 3; i++) {
			ServiceRequestResponse created = service.createRequest(owner.getId(),
				new ServiceRequestCreateRequest("水电", "成都", "高新区 " + i + " 号",
					new BigDecimal("98.50"), (short) 3, (short) 2, (short) 1,
					(short) 2, null));
			ServiceRequestResponse withCandidate = service.addCandidate(owner.getId(),
				created.id(), new CandidateCreateRequest(workerA.getId()));
			UUID bookingId = withCandidate.candidates().getFirst().id();
			bookingService.accept(workerA.getId(), bookingId);
			bookingService.proposeVisit(workerA.getId(), bookingId,
				proposedTime.plusSeconds(i));
		}
		Statistics statistics = entityManagerFactory.unwrap(SessionFactory.class)
			.getStatistics();
		statistics.setStatisticsEnabled(true);
		statistics.clear();

		List<ServiceRequestResponse> listed = service.listOwnerRequests(owner.getId());

		assertThat(listed).hasSize(3)
			.allSatisfy(item -> assertThat(item.candidates()).singleElement()
				.satisfies(candidate -> assertThat(candidate.proposedTime()).isNotNull()));
		assertThat(statistics.getPrepareStatementCount()).isLessThanOrEqualTo(3);
	}

	@Test
	void cancelRequestCancelsServiceRequestAndActiveCandidateBookings() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			houseRequest("旧房水电改造"));
		UUID requestId = created.id();
		service.addCandidate(owner.getId(), requestId,
			new CandidateCreateRequest(workerA.getId()));
		service.addCandidate(owner.getId(), requestId,
			new CandidateCreateRequest(workerB.getId()));

		ServiceRequestResponse result = service.cancelRequest(owner.getId(), requestId);

		assertThat(result.status()).isEqualTo(ServiceRequestStatus.CANCELLED);
		assertThat(requests.findById(requestId)).get()
			.extracting(ServiceRequest::getStatus).isEqualTo(ServiceRequestStatus.CANCELLED);

		var cancelledBookings = bookings.findByServiceRequestIdOrderByCreatedAtAsc(requestId);
		assertThat(cancelledBookings).hasSize(2);
		assertThat(cancelledBookings).allMatch(b ->
			b.getStatus() == BookingStatus.CANCELLED
				&& "需求已取消".equals(b.getCancelReason())
				&& "OWNER".equals(b.getCancelledBy()));
	}

	@Test
	void cancelRequestLeavesNonActiveBookingsUntouched() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			houseRequest("旧房水电改造"));
		UUID requestId = created.id();
		service.addCandidate(owner.getId(), requestId,
			new CandidateCreateRequest(workerA.getId()));
		service.addCandidate(owner.getId(), requestId,
			new CandidateCreateRequest(workerB.getId()));

		// workerB rejects first
		var bookingB = bookings.findByServiceRequestIdOrderByCreatedAtAsc(requestId)
			.stream().filter(b -> b.getWorkerUserId().equals(workerB.getId())).findFirst().orElseThrow();
		bookingB.reject();
		bookings.saveAndFlush(bookingB);

		service.cancelRequest(owner.getId(), requestId);

		var bookingsAfter = bookings.findByServiceRequestIdOrderByCreatedAtAsc(requestId);
		assertThat(bookingsAfter).filteredOn(b -> b.getWorkerUserId().equals(workerA.getId()))
			.singleElement().extracting(Booking::getStatus).isEqualTo(BookingStatus.CANCELLED);
		assertThat(bookingsAfter).filteredOn(b -> b.getWorkerUserId().equals(workerB.getId()))
			.singleElement().extracting(Booking::getStatus).isEqualTo(BookingStatus.REJECTED);
	}

	@Test
	void cancelAlreadyCancelledRequestThrows() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			houseRequest("旧房水电改造"));
		service.cancelRequest(owner.getId(), created.id());

		Throwable error = catchThrowable(() ->
			service.cancelRequest(owner.getId(), created.id()));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> assertThat(ex.code()).isEqualTo("SERVICE_REQUEST_ALREADY_CANCELLED"));
	}

	@Test
	void otherOwnerCannotCancelRequest() {
		User otherOwner = createUser("13900139101", UserRole.OWNER);
		ownerProfiles.saveAndFlush(OwnerProfile.create(otherOwner.getId(), "王业主",
			"成都", "新房装修", "锦江区 2 号", new BigDecimal("100.00")));
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			houseRequest("旧房水电改造"));

		Throwable error = catchThrowable(() ->
			service.cancelRequest(otherOwner.getId(), created.id()));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> assertThat(ex.code()).isEqualTo("SERVICE_REQUEST_NOT_FOUND"));
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}

	private ServiceRequestCreateRequest houseRequest(String remark) {
		return new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号",
			new BigDecimal("98.50"), (short) 3, (short) 2, (short) 1,
			(short) 2, remark);
	}
}
