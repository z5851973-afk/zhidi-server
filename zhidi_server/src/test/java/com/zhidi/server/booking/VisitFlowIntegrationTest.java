package com.zhidi.server.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class VisitFlowIntegrationTest extends MySqlContainerSupport {

	@Autowired
	BookingService bookingService;

	@Autowired
	BookingRepository bookings;

	@Autowired
	VisitProposalRepository visitProposals;

	@Autowired
	ServiceRequestRepository serviceRequests;

	@Autowired
	UserRepository users;

	@Autowired
	WorkerProfileRepository workerProfiles;

	@Autowired
	OwnerProfileRepository ownerProfiles;

	private User owner;
	private User worker;
	private BookingResponse acceptedBooking;

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

		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(), "林业主",
			"杭州", "旧房改造", "西湖区", new BigDecimal("88.00")));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(), "周师傅",
			"杭州", "泥工", 11, new BigDecimal("680.00"), "瓷砖铺贴"));

		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "泥工", "杭州", "西湖区", "厨房墙砖铺贴")).getId();

		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "林业主", owner.getPhone(),
			worker.getId(), "周师傅"));
		booking.accept();
		bookings.saveAndFlush(booking);
		acceptedBooking = bookingService.listForWorker(worker.getId()).get(0);
	}

	@Test
	void fullVisitFlowWorkerProposeOwnerAcceptBothArrive() {
		// 工人提出上门时间
		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.MINUTES);
		BookingResponse proposed = bookingService.proposeVisit(
			worker.getId(), acceptedBooking.id(), proposedTime);

		assertThat(proposed.status()).isEqualTo(BookingStatus.VISIT_PROPOSED);
		assertThat(visitProposals.count()).isEqualTo(1);

		// 业主确认
		BookingResponse scheduled = bookingService.acceptVisit(
			owner.getId(), acceptedBooking.id());
		assertThat(scheduled.status()).isEqualTo(BookingStatus.VISIT_SCHEDULED);
		assertThat(scheduled.proposedTime()).isEqualTo(proposedTime);

		// 工人标记到达
		BookingResponse workerArrived = bookingService.arrive(
			worker.getId(), acceptedBooking.id(), true);
		assertThat(workerArrived.status()).isEqualTo(BookingStatus.ARRIVAL_PENDING);
		assertThat(workerArrived.arrivalConfirmedByWorker()).isTrue();
		assertThat(workerArrived.arrivalConfirmedByOwner()).isFalse();

		// 业主标记到达 → 双方都确认 → ON_SITE
		BookingResponse onSite = bookingService.arrive(
			owner.getId(), acceptedBooking.id(), false);
		assertThat(onSite.status()).isEqualTo(BookingStatus.ON_SITE);
		assertThat(onSite.onSiteAt()).isNotNull();
	}

	@Test
	void ownerRejectsVisitProposalThenWorkerReproposes() {
		Instant firstTime = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.MINUTES);
		bookingService.proposeVisit(worker.getId(), acceptedBooking.id(), firstTime);

		// 业主拒绝
		BookingResponse rejected = bookingService.rejectVisit(
			owner.getId(), acceptedBooking.id(), "时间不合适，请改到下午");
		assertThat(rejected.status()).isEqualTo(BookingStatus.ACCEPTED);

		// 工人重新提出
		Instant secondTime = Instant.now().plus(2, ChronoUnit.DAYS).truncatedTo(ChronoUnit.MINUTES);
		BookingResponse reproposed = bookingService.proposeVisit(
			worker.getId(), acceptedBooking.id(), secondTime);
		assertThat(reproposed.status()).isEqualTo(BookingStatus.VISIT_PROPOSED);
		assertThat(visitProposals.count()).isEqualTo(2);
	}

	@Test
	void confirmArrivalBeforeBothArrivedReturnsConflict() {
		// 跳过 VISIT_PROPOSED 直接设置状态到 VISIT_SCHEDULED 来测试 confirm-arrival
		Booking booking = bookings.findById(acceptedBooking.id()).orElseThrow();
		booking.scheduleVisit();
		bookings.saveAndFlush(booking);

		// 只有工人标记到达
		bookingService.arrive(worker.getId(), acceptedBooking.id(), true);

		// 工人 try confirm-arrival（业主还没到达）→ CONFLICT
		Throwable error = catchThrowable(() ->
			bookingService.confirmArrival(worker.getId(), acceptedBooking.id(), true));
		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> {
				assertThat(ex.status().value()).isEqualTo(409);
				assertThat(ex.code()).isEqualTo("OWNER_NOT_ARRIVED");
			});
	}

	@Test
	void arriveWhenAlreadyOnSiteIsIdempotent() {
		// 完整流程到 ON_SITE
		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.MINUTES);
		bookingService.proposeVisit(worker.getId(), acceptedBooking.id(), proposedTime);
		bookingService.acceptVisit(owner.getId(), acceptedBooking.id());
		bookingService.arrive(worker.getId(), acceptedBooking.id(), true);
		bookingService.arrive(owner.getId(), acceptedBooking.id(), false);

		// 再次 arrive → 幂等，直接返回当前状态
		BookingResponse idempotent = bookingService.arrive(
			worker.getId(), acceptedBooking.id(), true);
		assertThat(idempotent.status()).isEqualTo(BookingStatus.ON_SITE);
	}

	@Test
	void proposeVisitOnlyFromAccepted() {
		// 创建另一个 pending booking
		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "泥工", "杭州", "西湖区", "另一单")).getId();

		Booking pendingBooking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "林业主", owner.getPhone(),
			worker.getId(), "周师傅"));

		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS);
		Throwable error = catchThrowable(() ->
			bookingService.proposeVisit(worker.getId(), pendingBooking.getId(), proposedTime));

		assertThat(error).isInstanceOf(IllegalStateException.class);
		assertThat(error.getMessage()).contains("ACCEPTED");
	}

	@Test
	void onSiteBookingCannotBeCancelled() {
		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.MINUTES);
		bookingService.proposeVisit(worker.getId(), acceptedBooking.id(), proposedTime);
		bookingService.acceptVisit(owner.getId(), acceptedBooking.id());
		bookingService.arrive(worker.getId(), acceptedBooking.id(), true);
		bookingService.arrive(owner.getId(), acceptedBooking.id(), false);

		Throwable error = catchThrowable(() ->
			bookingService.ownerCancel(owner.getId(), acceptedBooking.id(), "不想做了"));

		assertThat(error).isInstanceOf(IllegalStateException.class);
	}

	@Test
	void ownerAcceptVisitWithoutProposalReturnsConflict() {
		Throwable error = catchThrowable(() ->
			bookingService.acceptVisit(owner.getId(), acceptedBooking.id()));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> assertThat(ex.status().value()).isEqualTo(409));
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
