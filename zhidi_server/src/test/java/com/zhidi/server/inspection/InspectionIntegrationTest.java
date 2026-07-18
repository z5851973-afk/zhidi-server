package com.zhidi.server.inspection;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingService;
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
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class InspectionIntegrationTest extends MySqlContainerSupport {

	@Autowired
	InspectionService inspectionService;

	@Autowired
	BookingService bookingService;

	@Autowired
	InspectionNodeRepository nodeRepository;

	@Autowired
	InspectionRecordRepository recordRepository;

	@Autowired
	BookingRepository bookings;

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

	@BeforeEach
	void cleanDatabase() {
		recordRepository.deleteAll();
		nodeRepository.deleteAll();
		bookings.deleteAll();
		serviceRequests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();

		owner = createUser("13800138220", UserRole.OWNER);
		worker = createUser("13800138221", UserRole.WORKER);

		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(),
			"张业主", "杭州", "新房装修", "余杭区", new BigDecimal("120.00")));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(),
			"李师傅", "杭州", "木工", 8, new BigDecimal("500.00"), "木工经验丰富"));
	}

	@Test
	void createNodesForHiredBookingSucceeds() {
		UUID bookingId = createHiredBooking();

		List<CreateNodeRequest> requests = List.of(
			new CreateNodeRequest("水电验收", "检查水电管线铺设", 1),
			new CreateNodeRequest("木工验收", "检查木工制作质量", 2),
			new CreateNodeRequest("油漆验收", "检查油漆表面", 3)
		);

		List<InspectionNodeResponse> nodes = inspectionService.createNodes(
			worker.getId(), bookingId, requests);

		assertThat(nodes).hasSize(3);
		assertThat(nodes.get(0).name()).isEqualTo("水电验收");
		assertThat(nodes.get(0).status()).isEqualTo(InspectionNodeStatus.PENDING);
		assertThat(nodes.get(0).sortOrder()).isEqualTo(1);
	}

	@Test
	void createNodesForNonHiredBookingFails() {
		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "测试")).getId();

		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker.getId(), "李师傅"));
		booking.accept();
		bookings.saveAndFlush(booking);

		Throwable error = catchThrowable(() ->
			inspectionService.createNodes(worker.getId(), booking.getId(),
				List.of(new CreateNodeRequest("水电验收", null, 1))));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(409);
			assertThat(ex.code()).isEqualTo("INVALID_STATUS");
		});
	}

	@Test
	void fullInspectionFlowPassThenRecordsHistory() {
		UUID bookingId = createHiredBooking();

		// Worker creates nodes
		inspectionService.createNodes(worker.getId(), bookingId, List.of(
			new CreateNodeRequest("水电验收", "检查水电管线", 1)));

		List<InspectionNodeResponse> nodes = inspectionService.getNodes(bookingId);
		UUID nodeId = nodes.get(0).id();
		assertThat(nodes.get(0).status()).isEqualTo(InspectionNodeStatus.PENDING);

		// Worker requests inspection
		InspectionNodeResponse requested = inspectionService.requestInspection(
			worker.getId(), nodeId);
		assertThat(requested.status()).isEqualTo(InspectionNodeStatus.INSPECTING);

		// Owner inspects and passes
		InspectionRecordResponse record = inspectionService.inspect(
			owner.getId(), nodeId,
			new InspectRequest(InspectionResult.PASS, "验收通过", null));

		assertThat(record.result()).isEqualTo(InspectionResult.PASS);
		assertThat(record.comment()).isEqualTo("验收通过");
		assertThat(record.version()).isEqualTo(1);

		// Node status is PASSED
		InspectionNodeResponse node = inspectionService.getNodes(bookingId).get(0);
		assertThat(node.status()).isEqualTo(InspectionNodeStatus.PASSED);
	}

	@Test
	void failThenReinspectCreatesNewVersion() {
		UUID bookingId = createHiredBooking();

		inspectionService.createNodes(worker.getId(), bookingId, List.of(
			new CreateNodeRequest("水电验收", "检查水电管线", 1)));

		UUID nodeId = inspectionService.getNodes(bookingId).get(0).id();

		// Worker requests inspection
		inspectionService.requestInspection(worker.getId(), nodeId);

		// Owner fails
		inspectionService.inspect(owner.getId(), nodeId,
			new InspectRequest(InspectionResult.FAIL, "线路不整齐，需整改", null));

		InspectionNodeResponse node = inspectionService.getNodes(bookingId).get(0);
		assertThat(node.status()).isEqualTo(InspectionNodeStatus.FAILED);

		// Worker fixes and re-requests
		inspectionService.requestInspection(worker.getId(), nodeId);
		node = inspectionService.getNodes(bookingId).get(0);
		assertThat(node.status()).isEqualTo(InspectionNodeStatus.INSPECTING);

		// Owner passes on second inspection
		inspectionService.inspect(owner.getId(), nodeId,
			new InspectRequest(InspectionResult.PASS, "整改后通过", null));

		node = inspectionService.getNodes(bookingId).get(0);
		assertThat(node.status()).isEqualTo(InspectionNodeStatus.PASSED);

		// Records history has two versions
		List<InspectionRecordResponse> records = inspectionService.getRecords(nodeId);
		assertThat(records).hasSize(2);
		assertThat(records.get(0).version()).isEqualTo(2);
		assertThat(records.get(0).result()).isEqualTo(InspectionResult.PASS);
		assertThat(records.get(1).version()).isEqualTo(1);
		assertThat(records.get(1).result()).isEqualTo(InspectionResult.FAIL);
	}

	@Test
	void inspectNotInspectingStatusFails() {
		UUID bookingId = createHiredBooking();

		inspectionService.createNodes(worker.getId(), bookingId, List.of(
			new CreateNodeRequest("水电验收", null, 1)));

		UUID nodeId = inspectionService.getNodes(bookingId).get(0).id();

		Throwable error = catchThrowable(() ->
			inspectionService.inspect(owner.getId(), nodeId,
				new InspectRequest(InspectionResult.PASS, null, null)));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(409);
			assertThat(ex.code()).isEqualTo("INVALID_NODE_STATUS");
		});
	}

	@Test
	void inspectByNonOwnerFails() {
		UUID bookingId = createHiredBooking();

		inspectionService.createNodes(worker.getId(), bookingId, List.of(
			new CreateNodeRequest("水电验收", null, 1)));

		UUID nodeId = inspectionService.getNodes(bookingId).get(0).id();
		inspectionService.requestInspection(worker.getId(), nodeId);

		Throwable error = catchThrowable(() ->
			inspectionService.inspect(worker.getId(), nodeId,
				new InspectRequest(InspectionResult.PASS, null, null)));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(403);
			assertThat(ex.code()).isEqualTo("NOT_OWNER");
		});
	}

	@Test
	void requestInspectionByNonWorkerFails() {
		UUID bookingId = createHiredBooking();

		inspectionService.createNodes(worker.getId(), bookingId, List.of(
			new CreateNodeRequest("水电验收", null, 1)));

		UUID nodeId = inspectionService.getNodes(bookingId).get(0).id();

		Throwable error = catchThrowable(() ->
			inspectionService.requestInspection(owner.getId(), nodeId));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(403);
			assertThat(ex.code()).isEqualTo("NOT_WORKER");
		});
	}

	private UUID createHiredBooking() {
		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "测试木工")).getId();

		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker.getId(), "李师傅"));
		booking.accept();
		bookings.saveAndFlush(booking);

		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS)
			.truncatedTo(ChronoUnit.MINUTES);
		bookingService.proposeVisit(worker.getId(), booking.getId(), proposedTime);
		bookingService.acceptVisit(owner.getId(), booking.getId());
		bookingService.arrive(worker.getId(), booking.getId(), true);
		bookingService.arrive(owner.getId(), booking.getId(), false);
		booking.hire();
		return bookings.saveAndFlush(booking).getId();
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
