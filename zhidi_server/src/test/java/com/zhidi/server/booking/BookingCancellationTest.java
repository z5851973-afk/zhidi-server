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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class BookingCancellationTest extends MySqlContainerSupport {

	@Autowired
	BookingService bookingService;

	@Autowired
	BookingRepository bookings;

	@Autowired
	ServiceRequestRepository requests;

	@Autowired
	UserRepository users;

	@Autowired
	WorkerProfileRepository workerProfiles;

	@Autowired
	OwnerProfileRepository ownerProfiles;

	private User owner;
	private User worker;
	private User worker2;
	private User otherOwner;
	private Booking pendingBooking;
	private Booking acceptedBooking;

	@BeforeEach
	void cleanDatabase() {
		bookings.deleteAll();
		requests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();

		owner = createUser("13800138101", UserRole.OWNER);
		worker = createUser("13810138101", UserRole.WORKER);
		worker2 = createUser("13810138102", UserRole.WORKER);
		otherOwner = createUser("13800138201", UserRole.OWNER);

		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(), "林业主",
			"成都", "旧房改造", "高新区 1 号", new BigDecimal("88.00")));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(), "张师傅",
			"成都", "水电", 8, new BigDecimal("580.00"), "水电改造"));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker2.getId(), "李师傅",
			"成都", "水电", 5, new BigDecimal("480.00"), "水电施工"));

		ServiceRequest sr = requests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "水电", "成都", "高新区 1 号", "旧房水电改造"));

		pendingBooking = bookings.saveAndFlush(Booking.createCandidate(sr,
			owner.getId(), "林业主", owner.getPhone(),
			worker.getId(), "张师傅"));

		acceptedBooking = bookings.saveAndFlush(Booking.createCandidate(sr,
			owner.getId(), "林业主", owner.getPhone(),
			worker2.getId(), "李师傅"));
		acceptedBooking.accept();
		bookings.saveAndFlush(acceptedBooking);
	}

	@Test
	void ownerCancelsOwnPendingCandidateWithReason() {
		BookingResponse result = bookingService.ownerCancel(
			owner.getId(), pendingBooking.getId(), "预算调整");

		assertThat(result.status()).isEqualTo(BookingStatus.CANCELLED);
		assertThat(result.cancelledBy()).isEqualTo("OWNER");
		assertThat(result.cancelReason()).isEqualTo("预算调整");
		assertThat(result.cancelledAt()).isNotNull();
	}

	@Test
	void workerCancelsOwnAcceptedCandidateWithReason() {
		BookingResponse result = bookingService.workerCancel(
			worker2.getId(), acceptedBooking.getId(), "时间冲突");

		assertThat(result.status()).isEqualTo(BookingStatus.CANCELLED);
		assertThat(result.cancelledBy()).isEqualTo("WORKER");
		assertThat(result.cancelReason()).isEqualTo("时间冲突");
		assertThat(result.cancelledAt()).isNotNull();
	}

	@Test
	void unrelatedOwnerReceivesBookingNotFound() {
		Throwable error = catchThrowable(() ->
			bookingService.ownerCancel(otherOwner.getId(),
				pendingBooking.getId(), "不相关"));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> {
				assertThat(ex.status().value()).isEqualTo(404);
				assertThat(ex.code()).isEqualTo("BOOKING_NOT_FOUND");
			});
	}

	@Test
	void unrelatedWorkerReceivesBookingNotFound() {
		Throwable error = catchThrowable(() ->
			bookingService.workerCancel(owner.getId(),
				pendingBooking.getId(), "不相关"));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> {
				assertThat(ex.status().value()).isEqualTo(404);
				assertThat(ex.code()).isEqualTo("BOOKING_NOT_FOUND");
			});
	}

	@Test
	void cancelledBookingCannotBeCancelledAgain() {
		pendingBooking.cancel(BookingCancellationActor.OWNER,
			"预算调整", Instant.now());
		bookings.saveAndFlush(pendingBooking);

		Throwable error = catchThrowable(() ->
			bookingService.ownerCancel(owner.getId(),
				pendingBooking.getId(), "再取消一次"));

		assertThat(error).isInstanceOf(IllegalStateException.class);
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
