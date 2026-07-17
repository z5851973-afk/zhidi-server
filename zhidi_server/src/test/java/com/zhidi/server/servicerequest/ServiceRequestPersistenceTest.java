package com.zhidi.server.servicerequest;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class ServiceRequestPersistenceTest extends MySqlContainerSupport {

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
	private User firstWorker;
	private User secondWorker;

	@BeforeEach
	void cleanDatabase() {
		bookings.deleteAll();
		requests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();
		owner = createUser("13800138101", UserRole.OWNER);
		firstWorker = createUser("13800138102", UserRole.WORKER);
		secondWorker = createUser("13800138103", UserRole.WORKER);
		workerProfiles.saveAndFlush(WorkerProfile.create(firstWorker.getId(), "张师傅",
			"成都", "水电", 8, new BigDecimal("580.00"), "水电改造"));
		workerProfiles.saveAndFlush(WorkerProfile.create(secondWorker.getId(), "王师傅",
			"成都", "水电", 6, new BigDecimal("520.00"), "新房水电"));
		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(), "林业主",
			"成都", "旧房改造", "高新区 1 号", new BigDecimal("88.00")));
	}

	@Test
	void persistsMultipleCandidateBookingsUnderOneRequest() {
		ServiceRequest request = requests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "水电", "成都", "高新区 1 号", "旧房水电改造"));
		bookings.saveAndFlush(Booking.createCandidate(request, owner.getId(),
			"林业主", owner.getPhone(), firstWorker.getId(), "张师傅"));
		bookings.saveAndFlush(Booking.createCandidate(request, owner.getId(),
			"林业主", owner.getPhone(), secondWorker.getId(), "王师傅"));

		assertThat(bookings.findByServiceRequestIdOrderByCreatedAtAsc(request.getId()))
			.extracting(Booking::getWorkerUserId)
			.containsExactly(firstWorker.getId(), secondWorker.getId());
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
