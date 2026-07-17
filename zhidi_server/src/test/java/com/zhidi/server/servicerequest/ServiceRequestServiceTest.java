package com.zhidi.server.servicerequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingResponse;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class ServiceRequestServiceTest extends MySqlContainerSupport {

	@Autowired
	ServiceRequestService service;

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
	private User otherOwner;
	private User worker1;
	private User worker2;
	private User worker3;
	private User worker4;
	private User otherTradeWorker;

	@BeforeEach
	void cleanDatabase() {
		bookings.deleteAll();
		requests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();

		owner = createUser("13800138101", UserRole.OWNER);
		otherOwner = createUser("13800138201", UserRole.OWNER);

		worker1 = createUser("13810138101", UserRole.WORKER);
		worker2 = createUser("13810138102", UserRole.WORKER);
		worker3 = createUser("13810138103", UserRole.WORKER);
		worker4 = createUser("13810138104", UserRole.WORKER);
		otherTradeWorker = createUser("13810138201", UserRole.WORKER);

		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(), "林业主",
			"成都", "旧房改造", "高新区 1 号", new BigDecimal("88.00")));
		ownerProfiles.saveAndFlush(OwnerProfile.create(otherOwner.getId(), "陈业主",
			"成都", "新房装修", "武侯区", new BigDecimal("120.00")));

		workerProfiles.saveAndFlush(WorkerProfile.create(worker1.getId(), "张师傅",
			"成都", "水电", 8, new BigDecimal("580.00"), "水电改造"));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker2.getId(), "王师傅",
			"成都", "水电", 6, new BigDecimal("520.00"), "新房水电"));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker3.getId(), "李师傅",
			"成都", "水电", 10, new BigDecimal("620.00"), "老房水电翻新"));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker4.getId(), "孙师傅",
			"成都", "水电", 5, new BigDecimal("480.00"), "水电维修"));
		workerProfiles.saveAndFlush(WorkerProfile.create(otherTradeWorker.getId(), "赵师傅",
			"成都", "泥工", 12, new BigDecimal("650.00"), "瓷砖铺贴"));
	}

	@Test
	void ownerCanAddThreeDistinctSameTradeCandidates() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号", "旧房水电改造"));
		ServiceRequestResponse withOne = service.addCandidate(owner.getId(),
			created.id(), new CandidateCreateRequest(worker1.getId()));
		ServiceRequestResponse withTwo = service.addCandidate(owner.getId(),
			created.id(), new CandidateCreateRequest(worker2.getId()));
		ServiceRequestResponse withThree = service.addCandidate(owner.getId(),
			created.id(), new CandidateCreateRequest(worker3.getId()));

		assertThat(withThree.candidates()).hasSize(3);
		assertThat(withThree.candidates())
			.extracting(BookingResponse::workerUserId)
			.containsExactly(worker1.getId(), worker2.getId(), worker3.getId());
		assertThat(withThree.status()).isEqualTo(ServiceRequestStatus.COMPARING);
	}

	@Test
	void fourthActiveCandidateReturnsCandidateLimitReached() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号", null));
		service.addCandidate(owner.getId(), created.id(),
			new CandidateCreateRequest(worker1.getId()));
		service.addCandidate(owner.getId(), created.id(),
			new CandidateCreateRequest(worker2.getId()));
		service.addCandidate(owner.getId(), created.id(),
			new CandidateCreateRequest(worker3.getId()));

		Throwable error = catchThrowable(() ->
			service.addCandidate(owner.getId(), created.id(),
				new CandidateCreateRequest(worker4.getId())));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> {
				assertThat(ex.status().value()).isEqualTo(409);
				assertThat(ex.code()).isEqualTo("CANDIDANT_LIMIT_REACHED");
			});
	}

	@Test
	void duplicateWorkerReturnsCandidateAlreadyExists() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号", null));
		service.addCandidate(owner.getId(), created.id(),
			new CandidateCreateRequest(worker1.getId()));

		Throwable error = catchThrowable(() ->
			service.addCandidate(owner.getId(), created.id(),
				new CandidateCreateRequest(worker1.getId())));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> {
				assertThat(ex.status().value()).isEqualTo(409);
				assertThat(ex.code()).isEqualTo("CANDIDANT_ALREADY_EXISTS");
			});
	}

	@Test
	void crossTradeWorkerReturnsWorkerTradeMismatch() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号", null));

		Throwable error = catchThrowable(() ->
			service.addCandidate(owner.getId(), created.id(),
				new CandidateCreateRequest(otherTradeWorker.getId())));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> {
				assertThat(ex.status().value()).isEqualTo(409);
				assertThat(ex.code()).isEqualTo("WORKER_TRADE_MISMATCH");
			});
	}

	@Test
	void anotherOwnerReceivesServiceRequestNotFound() {
		ServiceRequestResponse created = service.createRequest(owner.getId(),
			new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号", null));

		Throwable error = catchThrowable(() ->
			service.addCandidate(otherOwner.getId(), created.id(),
				new CandidateCreateRequest(worker1.getId())));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class,
			ex -> {
				assertThat(ex.status().value()).isEqualTo(404);
				assertThat(ex.code()).isEqualTo("SERVICE_REQUEST_NOT_FOUND");
			});
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
