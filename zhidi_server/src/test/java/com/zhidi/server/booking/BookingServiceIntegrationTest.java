package com.zhidi.server.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.CandidateCreateRequest;
import com.zhidi.server.servicerequest.ServiceRequestCreateRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.servicerequest.ServiceRequestResponse;
import com.zhidi.server.servicerequest.ServiceRequestService;
import com.zhidi.server.servicerequest.ServiceRequestStatus;
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
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import jakarta.persistence.EntityManagerFactory;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@SpringBootTest
@ActiveProfiles("test")
class BookingServiceIntegrationTest extends MySqlContainerSupport {

	@Autowired
	BookingService service;

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
	ServiceRequestRepository serviceRequests;

	@Autowired
	ServiceRequestService serviceRequestService;

	@Autowired
	EntityManagerFactory entityManagerFactory;

	@Autowired
	PlatformTransactionManager transactionManager;

	private User owner;
	private User worker;
	private User otherWorker;

	@BeforeEach
	void cleanDatabase() {
		visitProposals.deleteAll();
		bookings.deleteAll();
		serviceRequests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();
		owner = createUser("13800138101", UserRole.OWNER);
		worker = createUser("13800138102", UserRole.WORKER);
		otherWorker = createUser("13800138103", UserRole.WORKER);
		workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(), "周师傅",
			"杭州", "泥工", 11, new BigDecimal("680.00"), "瓷砖铺贴"));
		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(), "林业主",
			"杭州", "旧房改造", "西湖区", new BigDecimal("88.00")));
	}

	@Test
	void ownerCreatesPendingBookingForVisibleWorker() {
		BookingResponse created = service.create(owner.getId(),
			bookingRequest(worker, "西湖区", "厨房墙砖铺贴"));

		assertThat(created.ownerUserId()).isEqualTo(owner.getId());
		assertThat(created.ownerName()).isEqualTo("林业主");
		assertThat(created.ownerPhone()).isEqualTo("13800138101");
		assertThat(created.workerUserId()).isEqualTo(worker.getId());
		assertThat(created.workerName()).isEqualTo("周师傅");
		assertThat(created.status()).isEqualTo(BookingStatus.PENDING);
		assertThat(created.trade()).isEqualTo("泥工");
		assertThat(created.serviceCity()).isEqualTo("杭州");
		assertThat(created.serviceAddress()).isEqualTo("西湖区");
		assertThat(created.remark()).isEqualTo("厨房墙砖铺贴");
		assertThat(bookings.count()).isEqualTo(1);
	}

	@Test
	void directBookingPersistsAndReturnsHouseInfoFromItsServiceRequest() {
		BookingResponse created = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", "西湖区",
			new BigDecimal("98.50"), (short) 3, (short) 2, (short) 1,
			(short) 2, "厨房墙砖铺贴"));

		assertThat(created.areaSqm()).isEqualByComparingTo("98.50");
		assertThat(created.bedroomCount()).isEqualTo((short) 3);
		assertThat(created.livingRoomCount()).isEqualTo((short) 2);
		assertThat(created.kitchenCount()).isEqualTo((short) 1);
		assertThat(created.bathroomCount()).isEqualTo((short) 2);
		ServiceRequest request = serviceRequests.findById(created.serviceRequestId())
			.orElseThrow();
		assertThat(request.getAreaSqm()).isEqualByComparingTo("98.50");
		assertThat(request.getBedroomCount()).isEqualTo((short) 3);
		assertThat(request.getLivingRoomCount()).isEqualTo((short) 2);
		assertThat(request.getKitchenCount()).isEqualTo((short) 1);
		assertThat(request.getBathroomCount()).isEqualTo((short) 2);
		assertThat(service.listForWorker(worker.getId())).singleElement()
			.satisfies(listed -> assertThat(listed.areaSqm())
				.isEqualByComparingTo("98.50"));
	}

	@Test
	void directBookingsForDifferentProjectsNeverReuseAServiceRequest() {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		BookingResponse first = service.create(owner.getId(),
			bookingRequest(worker, "武侯区旧项目 1 号", null));
		BookingResponse second = service.create(owner.getId(),
			bookingRequest(otherWorker, "武侯区新项目 2 号", null));

		assertThat(second.serviceRequestId()).isNotEqualTo(first.serviceRequestId());
		assertThat(second.serviceAddress()).isEqualTo("武侯区新项目 2 号");
	}

	@Test
	void directBookingsReuseTheSameCompleteProjectRequest() {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		BookingResponse first = service.create(owner.getId(),
			bookingRequest(worker, "西湖区同一项目", "同一需求"));
		BookingResponse second = service.create(owner.getId(),
			bookingRequest(otherWorker, "西湖区同一项目", "同一需求"));

		assertThat(second.serviceRequestId()).isEqualTo(first.serviceRequestId());
		assertThat(serviceRequests.count()).isEqualTo(1);
	}

	@Test
	void retryingTheSameDirectBookingReturnsTheOriginalBooking() {
		BookingRequest request = bookingRequest(worker, "西湖区同一项目", "同一需求");

		BookingResponse first = service.create(owner.getId(), request);
		BookingResponse retry = service.create(owner.getId(), request);

		assertThat(retry.id()).isEqualTo(first.id());
		assertThat(retry.serviceRequestId()).isEqualTo(first.serviceRequestId());
		assertThat(bookings.count()).isEqualTo(1);
		assertThat(serviceRequests.count()).isEqualTo(1);
	}

	@Test
	void directBookingReusesAnExactProjectAlreadyComparingCandidates() {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		User thirdWorker = createUser("13800138104", UserRole.WORKER);
		workerProfiles.saveAndFlush(WorkerProfile.create(thirdWorker.getId(), "陈师傅",
			"杭州", "泥工", 9, new BigDecimal("610.00"), "厨房翻新"));
		BookingResponse first = service.create(owner.getId(),
			bookingRequest(worker, "西湖区同一项目", "同一需求"));
		service.create(owner.getId(),
			bookingRequest(otherWorker, "西湖区同一项目", "同一需求"));
		assertThat(serviceRequests.findById(first.serviceRequestId())).get()
			.extracting(ServiceRequest::getStatus)
			.isEqualTo(ServiceRequestStatus.COMPARING);

		BookingResponse third = service.create(owner.getId(),
			bookingRequest(thirdWorker, "西湖区同一项目", "同一需求"));

		assertThat(third.serviceRequestId()).isEqualTo(first.serviceRequestId());
		assertThat(serviceRequests.count()).isEqualTo(1);
	}

	@Test
	void fourthDirectBookingForTheSameProjectStartsANewRequest() {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		User thirdWorker = createEligibleWorker("13800138104", "陈师傅", 9);
		User fourthWorker = createEligibleWorker("13800138105", "吴师傅", 10);
		BookingRequest firstRequest = bookingRequest(worker, "西湖区同一项目", null);

		BookingResponse first = service.create(owner.getId(), firstRequest);
		BookingResponse second = service.create(owner.getId(),
			bookingRequest(otherWorker, "西湖区同一项目", null));
		BookingResponse third = service.create(owner.getId(),
			bookingRequest(thirdWorker, "西湖区同一项目", null));
		BookingResponse fourth = service.create(owner.getId(),
			bookingRequest(fourthWorker, "西湖区同一项目", null));
		BookingResponse retry = service.create(owner.getId(), firstRequest);

		assertThat(List.of(second.serviceRequestId(), third.serviceRequestId()))
			.containsOnly(first.serviceRequestId());
		assertThat(fourth.serviceRequestId()).isNotEqualTo(first.serviceRequestId());
		assertThat(retry.id()).isEqualTo(first.id());
		assertThat(bookings.count()).isEqualTo(4);
		assertThat(serviceRequests.count()).isEqualTo(2);
		assertThat(bookings.countActiveCandidates(first.serviceRequestId(),
			BookingStatus.CANDIDATE_TERMINAL_STATUSES)).isEqualTo(3);
		assertThat(bookings.countActiveCandidates(fourth.serviceRequestId(),
			BookingStatus.CANDIDATE_TERMINAL_STATUSES)).isEqualTo(1);
	}

	@Test
	void directBookingAndCandidateApiShareTheLastCandidateSlotWithoutOverflow()
			throws Exception {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		User thirdWorker = createEligibleWorker("13800138104", "陈师傅", 9);
		User directWorker = createEligibleWorker("13800138105", "吴师傅", 10);
		ServiceRequestResponse request = serviceRequestService.createRequest(owner.getId(),
			houseRequest(null));
		serviceRequestService.addCandidate(owner.getId(), request.id(),
			new CandidateCreateRequest(worker.getId()));
		serviceRequestService.addCandidate(owner.getId(), request.id(),
			new CandidateCreateRequest(otherWorker.getId()));

		CountDownLatch ownerLocked = new CountDownLatch(1);
		CountDownLatch releaseOwner = new CountDownLatch(1);
		CountDownLatch contendersReady = new CountDownLatch(2);
		CountDownLatch startContenders = new CountDownLatch(1);
		ExecutorService executor = Executors.newFixedThreadPool(3);
		Future<?> lockHolder = executor.submit(() ->
			new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
				users.findByIdForUpdate(owner.getId()).orElseThrow();
				ownerLocked.countDown();
				await(releaseOwner);
			}));
		assertThat(ownerLocked.await(10, TimeUnit.SECONDS)).isTrue();

		Future<BookingResponse> direct = executor.submit(() -> {
			contendersReady.countDown();
			startContenders.await();
			return service.create(owner.getId(),
				bookingRequest(directWorker, null, null));
		});
		Future<Throwable> add = executor.submit(() -> {
			contendersReady.countDown();
			startContenders.await();
			return catchThrowable(() -> serviceRequestService.addCandidate(owner.getId(),
				request.id(), new CandidateCreateRequest(thirdWorker.getId())));
		});
		assertThat(contendersReady.await(10, TimeUnit.SECONDS)).isTrue();
		startContenders.countDown();

		boolean candidateMutationBypassedOwnerLock;
		try {
			add.get(2, TimeUnit.SECONDS);
			candidateMutationBypassedOwnerLock = true;
		} catch (TimeoutException expected) {
			candidateMutationBypassedOwnerLock = false;
		} finally {
			releaseOwner.countDown();
		}

		try {
			BookingResponse directResult = direct.get(10, TimeUnit.SECONDS);
			Throwable addResult = add.get(10, TimeUnit.SECONDS);
			lockHolder.get(10, TimeUnit.SECONDS);

			assertThat(candidateMutationBypassedOwnerLock).isFalse();
			assertThat(directResult).isNotNull();
			if (addResult != null) {
				assertThat(addResult).isInstanceOfSatisfying(BusinessException.class,
					ex -> assertThat(ex.code()).isEqualTo("CANDIDATE_LIMIT_REACHED"));
			}
			assertThat(bookings.countActiveCandidates(request.id(),
				BookingStatus.CANDIDATE_TERMINAL_STATUSES)).isEqualTo(3);
			assertThat(serviceRequests.findByOwnerUserIdOrderByCreatedAtDesc(owner.getId()))
				.allSatisfy(item -> assertThat(bookings.countActiveCandidates(item.getId(),
					BookingStatus.CANDIDATE_TERMINAL_STATUSES)).isLessThanOrEqualTo(3));
		} finally {
			releaseOwner.countDown();
			executor.shutdownNow();
		}
	}

	@Test
	void concurrentRetryWithoutOwnerProfileCreatesOneRequestAndBooking()
			throws Exception {
		ownerProfiles.deleteAll();
		BookingRequest request = bookingRequest(worker, "西湖区并发项目", "网络重试");
		CountDownLatch ready = new CountDownLatch(2);
		CountDownLatch start = new CountDownLatch(1);
		ExecutorService executor = Executors.newFixedThreadPool(2);
		try {
			Future<BookingResponse> first = executor.submit(() -> {
				ready.countDown();
				start.await();
				return service.create(owner.getId(), request);
			});
			Future<BookingResponse> retry = executor.submit(() -> {
				ready.countDown();
				start.await();
				return service.create(owner.getId(), request);
			});
			ready.await();
			start.countDown();

			assertThat(retry.get().id()).isEqualTo(first.get().id());
		} finally {
			executor.shutdownNow();
		}
		assertThat(bookings.count()).isEqualTo(1);
		assertThat(serviceRequests.count()).isEqualTo(1);
	}

	@Test
	void bookingListLoadsRequestsAndVisitProposalsInFixedQueryCount() {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS)
			.truncatedTo(ChronoUnit.MINUTES);
		for (int i = 0; i < 3; i++) {
			User target = i % 2 == 0 ? worker : otherWorker;
			BookingResponse created = service.create(owner.getId(),
				bookingRequest(target, "西湖区批量项目 " + i, null));
			service.accept(target.getId(), created.id());
			service.proposeVisit(target.getId(), created.id(), proposedTime.plusSeconds(i));
		}
		Statistics statistics = entityManagerFactory.unwrap(SessionFactory.class)
			.getStatistics();
		statistics.setStatisticsEnabled(true);
		statistics.clear();

		List<BookingResponse> listed = service.listForOwner(owner.getId());

		assertThat(listed).hasSize(3)
			.allSatisfy(item -> assertThat(item.proposedTime()).isNotNull());
		assertThat(statistics.getPrepareStatementCount()).isLessThanOrEqualTo(3);
	}

	@Test
	void listsBookingsForOwnerAndWorkerNewestFirst() {
		BookingResponse first = service.create(owner.getId(),
			bookingRequest(worker, "西湖区", "第一单"));
		BookingResponse second = service.create(owner.getId(),
			bookingRequest(worker, "滨江区", "第二单"));

		assertThat(service.listForOwner(owner.getId()).stream().map(BookingResponse::id))
			.containsExactly(second.id(), first.id());
		assertThat(service.listForWorker(worker.getId()).stream().map(BookingResponse::id))
			.containsExactly(second.id(), first.id());
		assertThat(service.listForWorker(otherWorker.getId())).isEmpty();
	}

	@Test
	void bookedWorkerAcceptsAndRejectsPendingBookings() {
		BookingResponse acceptTarget = service.create(owner.getId(),
			bookingRequest(worker, "西湖区待接受项目", null));
		BookingResponse rejectTarget = service.create(owner.getId(),
			bookingRequest(worker, "滨江区待拒绝项目", null));

		assertThat(service.accept(worker.getId(), acceptTarget.id()).status())
			.isEqualTo(BookingStatus.ACCEPTED);
		assertThat(service.reject(worker.getId(), rejectTarget.id()).status())
			.isEqualTo(BookingStatus.REJECTED);
	}

	@Test
	void otherWorkerCannotAcceptBooking() {
		BookingResponse booking = service.create(owner.getId(),
			bookingRequest(worker, null, null));

		Throwable error = catchThrowable(() ->
			service.accept(otherWorker.getId(), booking.id()));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> assertThat(ex.code()).isEqualTo("BOOKING_NOT_FOUND"));
		assertThat(service.listForWorker(worker.getId()))
			.singleElement()
			.extracting(BookingResponse::status)
			.isEqualTo(BookingStatus.PENDING);
	}

	@Test
	void rejectsBookingForIncompleteWorkerProfile() {
		workerProfiles.deleteAll();

		Throwable error = catchThrowable(() ->
			service.create(owner.getId(), bookingRequest(worker, null, null)));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> assertThat(ex.code()).isEqualTo("WORKER_NOT_FOUND"));
		assertThat(bookings.count()).isZero();
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}

	private User createEligibleWorker(String phone, String name,
			int experienceYears) {
		User created = createUser(phone, UserRole.WORKER);
		workerProfiles.saveAndFlush(WorkerProfile.create(created.getId(), name,
			"杭州", "泥工", experienceYears, new BigDecimal("600.00"), "泥工施工"));
		return created;
	}

	private void await(CountDownLatch latch) {
		try {
			latch.await();
		} catch (InterruptedException error) {
			Thread.currentThread().interrupt();
			throw new IllegalStateException(error);
		}
	}

	@Test
	void candidatesAcceptIndependentlyAndRemainComparable() {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		ServiceRequestResponse request = serviceRequestService.createRequest(owner.getId(),
			houseRequest(null));
		BookingResponse first = serviceRequestService.addCandidate(owner.getId(),
			request.id(), new CandidateCreateRequest(worker.getId())).candidates().getFirst();
		BookingResponse second = serviceRequestService.addCandidate(owner.getId(),
			request.id(), new CandidateCreateRequest(otherWorker.getId())).candidates().get(1);
		UUID srId = request.id();

		service.accept(worker.getId(), first.id());
		service.accept(otherWorker.getId(), second.id());

		assertThat(bookings.findById(first.id())).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.ACCEPTED);
		assertThat(bookings.findById(second.id())).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.ACCEPTED);
		assertThat(serviceRequests.findById(srId)).get()
			.extracting(ServiceRequest::getStatus).isEqualTo(ServiceRequestStatus.COMPARING);
	}

	@Test
	void rejectWithRemainingCandidatesDoesNotRevertServiceRequest() {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		ServiceRequestResponse request = serviceRequestService.createRequest(owner.getId(),
			houseRequest(null));
		BookingResponse first = serviceRequestService.addCandidate(owner.getId(),
			request.id(), new CandidateCreateRequest(worker.getId())).candidates().getFirst();
		serviceRequestService.addCandidate(owner.getId(), request.id(),
			new CandidateCreateRequest(otherWorker.getId()));
		UUID srId = request.id();

		service.reject(worker.getId(), first.id());

		assertThat(bookings.findById(first.id())).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.REJECTED);
		// 还有候选人，ServiceRequest 应保持 OPEN
		assertThat(serviceRequests.findById(srId)).get()
			.extracting(ServiceRequest::getStatus).isEqualTo(ServiceRequestStatus.OPEN);
	}

	@Test
	void rejectLastCandidateRevertsServiceRequestToOpen() {
		BookingResponse only = service.create(owner.getId(),
			bookingRequest(worker, null, null));
		UUID srId = only.serviceRequestId();

		service.reject(worker.getId(), only.id());

		assertThat(bookings.findById(only.id())).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.REJECTED);
		// 已无候选人，ServiceRequest 回退到 OPEN
		assertThat(serviceRequests.findById(srId)).get()
			.extracting(ServiceRequest::getStatus).isEqualTo(ServiceRequestStatus.OPEN);
	}

	private BookingRequest bookingRequest(User targetWorker, String address,
			String remark) {
		return new BookingRequest(targetWorker.getId(), "泥工", "杭州", address,
			new BigDecimal("98.50"), (short) 3, (short) 2, (short) 1,
			(short) 2, remark);
	}

	private ServiceRequestCreateRequest houseRequest(String remark) {
		return new ServiceRequestCreateRequest("泥工", "杭州", null,
			new BigDecimal("98.50"), (short) 3, (short) 2, (short) 1,
			(short) 2, remark);
	}
}
