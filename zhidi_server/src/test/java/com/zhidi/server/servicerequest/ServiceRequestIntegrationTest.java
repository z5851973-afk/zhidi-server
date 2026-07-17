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
import java.util.UUID;
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
	ServiceRequestRepository requests;

	@Autowired
	BookingRepository bookings;

	@Autowired
	UserRepository users;

	@Autowired
	WorkerProfileRepository workerProfiles;

	@Autowired
	OwnerProfileRepository ownerProfiles;

	private User owner;
	private User workerA;
	private User workerB;

	@BeforeEach
	void cleanDatabase() {
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
	void cancelRequestCancelsServiceRequestAndActiveCandidateBookings() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号", "旧房水电改造"));
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
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号", "旧房水电改造"));
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
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号", "旧房水电改造"));
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
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号", "旧房水电改造"));

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
}
