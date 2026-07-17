package com.zhidi.server.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.servicerequest.ServiceRequestStatus;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class BookingServiceIntegrationTest extends MySqlContainerSupport {

	@Autowired
	BookingService service;

	@Autowired
	BookingRepository bookings;

	@Autowired
	UserRepository users;

	@Autowired
	WorkerProfileRepository workerProfiles;

	@Autowired
	OwnerProfileRepository ownerProfiles;

	@Autowired
	ServiceRequestRepository serviceRequests;

	private User owner;
	private User worker;
	private User otherWorker;

	@BeforeEach
	void cleanDatabase() {
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
		BookingResponse created = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", "西湖区", "厨房墙砖铺贴"));

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
	void listsBookingsForOwnerAndWorkerNewestFirst() {
		BookingResponse first = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", "西湖区", "第一单"));
		BookingResponse second = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", "滨江区", "第二单"));

		assertThat(service.listForOwner(owner.getId()).stream().map(BookingResponse::id))
			.containsExactly(second.id(), first.id());
		assertThat(service.listForWorker(worker.getId()).stream().map(BookingResponse::id))
			.containsExactly(second.id(), first.id());
		assertThat(service.listForWorker(otherWorker.getId())).isEmpty();
	}

	@Test
	void bookedWorkerAcceptsAndRejectsPendingBookings() {
		BookingResponse acceptTarget = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", null, null));
		BookingResponse rejectTarget = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", null, null));

		assertThat(service.accept(worker.getId(), acceptTarget.id()).status())
			.isEqualTo(BookingStatus.ACCEPTED);
		assertThat(service.reject(worker.getId(), rejectTarget.id()).status())
			.isEqualTo(BookingStatus.REJECTED);
	}

	@Test
	void otherWorkerCannotAcceptBooking() {
		BookingResponse booking = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", null, null));

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
			service.create(owner.getId(), new BookingRequest(
				worker.getId(), "泥工", "杭州", null, null)));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> assertThat(ex.code()).isEqualTo("WORKER_NOT_FOUND"));
		assertThat(bookings.count()).isZero();
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}

	@Test
	void acceptElectsWinnerMarksOthersNotSelectedAdvancesServiceRequest() {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		BookingResponse first = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", null, null));
		UUID srId = first.serviceRequestId();
		BookingResponse second = service.create(owner.getId(), new BookingRequest(
			otherWorker.getId(), "泥工", "杭州", null, null));

		service.accept(worker.getId(), first.id());

		// 当选者状态为 ACCEPTED
		assertThat(bookings.findById(first.id())).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.ACCEPTED);
		// 其他候选人 NOT_SELECTED
		assertThat(bookings.findById(second.id())).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.NOT_SELECTED);
		// ServiceRequest 推进到 WORKER_SELECTED
		assertThat(serviceRequests.findById(srId)).get()
			.extracting(ServiceRequest::getStatus).isEqualTo(ServiceRequestStatus.WORKER_SELECTED);
	}

	@Test
	void rejectWithRemainingCandidatesDoesNotRevertServiceRequest() {
		workerProfiles.saveAndFlush(WorkerProfile.create(otherWorker.getId(), "李师傅",
			"杭州", "泥工", 8, new BigDecimal("580.00"), "老房翻新"));
		BookingResponse first = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", null, null));
		UUID srId = first.serviceRequestId();
		service.create(owner.getId(), new BookingRequest(
			otherWorker.getId(), "泥工", "杭州", null, null));

		service.reject(worker.getId(), first.id());

		assertThat(bookings.findById(first.id())).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.REJECTED);
		// 还有候选人，ServiceRequest 应保持 OPEN
		assertThat(serviceRequests.findById(srId)).get()
			.extracting(ServiceRequest::getStatus).isEqualTo(ServiceRequestStatus.OPEN);
	}

	@Test
	void rejectLastCandidateRevertsServiceRequestToOpen() {
		BookingResponse only = service.create(owner.getId(), new BookingRequest(
			worker.getId(), "泥工", "杭州", null, null));
		UUID srId = only.serviceRequestId();
		service.accept(worker.getId(), only.id());

		service.reject(worker.getId(), only.id());

		assertThat(bookings.findById(only.id())).get()
			.extracting(Booking::getStatus).isEqualTo(BookingStatus.REJECTED);
		// 已无候选人，ServiceRequest 回退到 OPEN
		assertThat(serviceRequests.findById(srId)).get()
			.extracting(ServiceRequest::getStatus).isEqualTo(ServiceRequestStatus.OPEN);
	}
}
