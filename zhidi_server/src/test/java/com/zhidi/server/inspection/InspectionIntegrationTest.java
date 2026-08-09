package com.zhidi.server.inspection;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingService;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.infrastructure.storage.FileStorageService;
import com.zhidi.server.notification.BusinessEvent;
import com.zhidi.server.notification.BusinessEventRepository;
import com.zhidi.server.notification.BusinessEventStreamRepository;
import com.zhidi.server.notification.BusinessEventType;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.mock.web.MockMultipartFile;

@SpringBootTest(properties =
	"zhidi.upload.root=target/test-uploads/inspection-integration")
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
	InspectionSubmissionRepository submissionRepository;

	@Autowired
	InspectionEvidenceAssetRepository evidenceAssetRepository;

	@Autowired
	FileStorageService fileStorageService;

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

	@Autowired
	BusinessEventRepository businessEvents;

	@Autowired
	BusinessEventStreamRepository businessEventStreams;

	private User owner;
	private User worker;

	@AfterEach
	void deleteUploadedEvidenceFiles() {
		evidenceAssetRepository.findAll().forEach(asset ->
			fileStorageService.delete(asset.getObjectKey()));
	}

	@BeforeEach
	void cleanDatabase() {
		businessEvents.deleteAll();
		businessEventStreams.deleteAll();
		recordRepository.deleteAll();
		submissionRepository.deleteAll();
		evidenceAssetRepository.deleteAll();
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
			new CreateNodeRequest("  木工基层验收  ", "检查木工基层", 1),
			new CreateNodeRequest("木工收口验收", "检查木工收口", 2),
			new CreateNodeRequest("木工成品验收", "检查木工作品", 3)
		);

		List<InspectionNodeResponse> nodes = inspectionService.createNodes(
			worker.getId(), bookingId, requests);

		assertThat(nodes).hasSize(3);
		assertThat(nodes.get(0).name()).isEqualTo("木工基层验收");
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
			new CreateNodeRequest("木工验收", "检查木作质量", 1)));

		List<InspectionNodeResponse> nodes = inspectionService.getNodes(
			owner.getId(), bookingId);
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
		InspectionNodeResponse node = inspectionService.getNodes(
			owner.getId(), bookingId).get(0);
		assertThat(node.status()).isEqualTo(InspectionNodeStatus.PASSED);
	}

	@Test
	void failedInspectionRequiresRectificationComment() {
		UUID bookingId = createHiredBooking();
		UUID nodeId = inspectionService.createNodes(worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", "检查木作质量", 1)))
			.get(0).id();
		String workerPhoto = uploadEvidence(worker.getId(), nodeId, "worker.jpg");
		inspectionService.requestInspection(worker.getId(), nodeId,
			new InspectionSubmissionRequest("木作完成，请验收", List.of(workerPhoto)));

		Throwable error = catchThrowable(() -> inspectionService.inspect(
			owner.getId(), nodeId,
			new InspectRequest(InspectionResult.FAIL, "   ", List.of())));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("RECTIFICATION_COMMENT_REQUIRED");
		});
		assertThat(recordRepository.findByNodeIdOrderByInspectionVersionDesc(nodeId))
			.isEmpty();
		assertThat(nodeRepository.findById(nodeId).orElseThrow().getStatus())
			.isEqualTo(InspectionNodeStatus.INSPECTING);
	}

	@Test
	void workerSubmissionsAndOwnerDecisionsFormOrderedMultiRoundTimeline() {
		UUID bookingId = createHiredBooking();
		UUID nodeId = inspectionService.createNodes(worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", "检查木作质量", 1)))
			.get(0).id();
		String workerRound1 = uploadEvidence(worker.getId(), nodeId,
			"worker-round-1.jpg");

		inspectionService.requestInspection(worker.getId(), nodeId,
			new InspectionSubmissionRequest("首轮木作完成", List.of(workerRound1)));
		String ownerRound1 = uploadEvidence(owner.getId(), nodeId,
			"owner-round-1.jpg");
		inspectionService.inspect(owner.getId(), nodeId,
			new InspectRequest(InspectionResult.FAIL, "柜门缝隙需要整改",
				List.of(ownerRound1)));
		String workerRound2 = uploadEvidence(worker.getId(), nodeId,
			"worker-round-2.jpg");
		inspectionService.requestInspection(worker.getId(), nodeId,
			new InspectionSubmissionRequest("已调整柜门缝隙，请复验",
				List.of(workerRound2)));
		String ownerRound2 = uploadEvidence(owner.getId(), nodeId,
			"owner-round-2.jpg");
		inspectionService.inspect(owner.getId(), nodeId,
			new InspectRequest(InspectionResult.PASS, "整改后通过",
				List.of(ownerRound2)));

		List<InspectionTimelineResponse> timeline = inspectionService.getTimeline(
			owner.getId(), nodeId);
		assertThat(timeline).hasSize(4);
		assertThat(timeline).extracting(InspectionTimelineResponse::type)
			.containsExactly("WORKER_SUBMISSION", "OWNER_DECISION",
				"WORKER_SUBMISSION", "OWNER_DECISION");
		assertThat(timeline).extracting(InspectionTimelineResponse::round)
			.containsExactly(1, 1, 2, 2);
		assertThat(timeline).extracting(InspectionTimelineResponse::actorRole)
			.containsExactly("WORKER", "OWNER", "WORKER", "OWNER");
		assertThat(timeline.get(0).note()).isEqualTo("首轮木作完成");
		assertThat(timeline.get(1).note()).isEqualTo("柜门缝隙需要整改");
		assertThat(timeline.get(2).photos()).containsExactly(workerRound2);
		assertThat(timeline.get(3).result()).isEqualTo(InspectionResult.PASS);

		List<BusinessEvent> ownerEvents = businessEvents
			.findByRecipientUserIdOrderBySequenceNoAsc(owner.getId());
		assertThat(ownerEvents)
			.extracting(BusinessEvent::getEventType)
			.containsExactly(
				BusinessEventType.INSPECTION_REQUESTED,
				BusinessEventType.INSPECTION_REQUESTED);
		assertThat(ownerEvents)
			.extracting(event -> event.getPayload().get("round"))
			.containsExactly(1, 2);

		List<BusinessEvent> workerEvents = businessEvents
			.findByRecipientUserIdOrderBySequenceNoAsc(worker.getId());
		assertThat(workerEvents)
			.extracting(BusinessEvent::getEventType)
			.containsExactly(
				BusinessEventType.INSPECTION_RECTIFICATION_REQUIRED,
				BusinessEventType.INSPECTION_PASSED);
		assertThat(workerEvents)
			.extracting(event -> event.getPayload().get("round"))
			.containsExactly(1, 2);
		assertThat(workerEvents)
			.extracting(event -> event.getPayload().get("result"))
			.containsExactly("FAIL", "PASS");

		List<UUID> submissionIds = submissionRepository
			.findByNodeIdOrderBySubmissionVersionAsc(nodeId).stream()
			.map(InspectionSubmission::getId)
			.toList();
		List<UUID> recordIds = recordRepository
			.findByNodeIdOrderByInspectionVersionDesc(nodeId).reversed().stream()
			.map(InspectionRecord::getId)
			.toList();
		assertThat(ownerEvents)
			.extracting(BusinessEvent::getIdempotencyKey)
			.containsExactly(
				"inspection-submission:" + submissionIds.get(0),
				"inspection-submission:" + submissionIds.get(1));
		assertThat(workerEvents)
			.extracting(BusinessEvent::getIdempotencyKey)
			.containsExactly(
				"inspection-record:" + recordIds.get(0),
				"inspection-record:" + recordIds.get(1));
		assertThat(ownerEvents).allSatisfy(event -> {
			assertThat(event.getActorUserId()).isEqualTo(worker.getId());
			assertThat(event.getAggregateType()).isEqualTo("INSPECTION_NODE");
			assertThat(event.getAggregateId()).isEqualTo(nodeId);
			assertThat(event.getBookingId()).isEqualTo(bookingId);
		});
		assertThat(workerEvents).allSatisfy(event -> {
			assertThat(event.getActorUserId()).isEqualTo(owner.getId());
			assertThat(event.getAggregateType()).isEqualTo("INSPECTION_NODE");
			assertThat(event.getAggregateId()).isEqualTo(nodeId);
			assertThat(event.getBookingId()).isEqualTo(bookingId);
		});
	}

	@Test
	void concurrentOwnerDecisionsCreateOnlyOneInspectionVersion() throws Exception {
		UUID bookingId = createHiredBooking();
		UUID nodeId = inspectionService.createNodes(worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", "检查木作质量", 1)))
			.get(0).id();
		inspectionService.requestInspection(worker.getId(), nodeId,
			new InspectionSubmissionRequest("木作完成", List.of()));

		ExecutorService executor = Executors.newFixedThreadPool(2);
		CountDownLatch ready = new CountDownLatch(2);
		CountDownLatch start = new CountDownLatch(1);
		try {
			java.util.concurrent.Callable<Object> decision = () -> {
				ready.countDown();
				start.await(5, TimeUnit.SECONDS);
				try {
					return inspectionService.inspect(owner.getId(), nodeId,
						new InspectRequest(InspectionResult.PASS, "并发验收通过", List.of()));
				} catch (Throwable error) {
					return error;
				}
			};
			Future<Object> first = executor.submit(decision);
			Future<Object> second = executor.submit(decision);
			assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
			start.countDown();

			List<Object> results = List.of(
				first.get(10, TimeUnit.SECONDS),
				second.get(10, TimeUnit.SECONDS));
			assertThat(results.stream()
				.filter(InspectionRecordResponse.class::isInstance).count())
				.as("concurrent decision results: %s", results)
				.isEqualTo(1);
			assertThat(results.stream()
				.filter(BusinessException.class::isInstance).count())
				.isEqualTo(1);
		} finally {
			executor.shutdownNow();
		}

		List<InspectionRecord> records = recordRepository
			.findByNodeIdOrderByInspectionVersionDesc(nodeId);
		assertThat(records).hasSize(1);
		assertThat(records.get(0).getInspectionVersion()).isEqualTo(1);
	}

	@Test
	void inspectionEvidenceRejectsForeignCategoryAndTooManyPhotos() {
		UUID bookingId = createHiredBooking();
		UUID nodeId = inspectionService.createNodes(worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", null, 1))).get(0).id();

		Throwable foreignCategory = catchThrowable(() ->
			inspectionService.requestInspection(worker.getId(), nodeId,
				new InspectionSubmissionRequest("请验收", List.of(
					"/uploads/daily-reports/2026/08/08/not-inspection.jpg"))));
		assertThat(foreignCategory).isInstanceOfSatisfying(
			BusinessException.class, ex -> {
				assertThat(ex.status().value()).isEqualTo(400);
				assertThat(ex.code()).isEqualTo("INVALID_INSPECTION_PHOTO");
			});

		List<String> tenPhotos = java.util.stream.IntStream.range(0, 10)
			.mapToObj(index -> "/uploads/inspection-evidence/2026/08/08/" + index + ".jpg")
			.toList();
		Throwable tooMany = catchThrowable(() ->
			inspectionService.requestInspection(worker.getId(), nodeId,
				new InspectionSubmissionRequest("请验收", tenPhotos)));
		assertThat(tooMany).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("TOO_MANY_INSPECTION_PHOTOS");
		});
	}

	@Test
	void inspectionEvidenceRejectsUnregisteredPlatformLookingUrl() {
		UUID bookingId = createHiredBooking();
		UUID nodeId = inspectionService.createNodes(worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", null, 1))).get(0).id();

		Throwable error = catchThrowable(() ->
			inspectionService.requestInspection(worker.getId(), nodeId,
				new InspectionSubmissionRequest("请验收", List.of(
					"/uploads/inspection-evidence/2026/08/09/forged.jpg"))));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("INVALID_INSPECTION_PHOTO");
		});
	}

	@Test
	void inspectionEvidenceCannotBeReusedByAnotherActorOrNode() {
		UUID bookingId = createHiredBooking();
		List<InspectionNodeResponse> nodes = inspectionService.createNodes(
			worker.getId(), bookingId, List.of(
				new CreateNodeRequest("木工基层验收", null, 1),
				new CreateNodeRequest("木工收口验收", null, 2)));
		String workerEvidence = uploadEvidence(
			worker.getId(), nodes.get(0).id(), "worker-owned.jpg");

		inspectionService.requestInspection(worker.getId(), nodes.get(0).id(),
			new InspectionSubmissionRequest("请验收", List.of(workerEvidence)));
		Throwable wrongUploader = catchThrowable(() -> inspectionService.inspect(
			owner.getId(), nodes.get(0).id(),
			new InspectRequest(InspectionResult.PASS, "通过", List.of(workerEvidence))));
		assertThat(wrongUploader).isInstanceOfSatisfying(BusinessException.class, ex ->
			assertThat(ex.code()).isEqualTo("INVALID_INSPECTION_PHOTO"));

		Throwable wrongNode = catchThrowable(() ->
			inspectionService.requestInspection(worker.getId(), nodes.get(1).id(),
				new InspectionSubmissionRequest("请验收", List.of(workerEvidence))));
		assertThat(wrongNode).isInstanceOfSatisfying(BusinessException.class, ex ->
			assertThat(ex.code()).isEqualTo("INVALID_INSPECTION_PHOTO"));
	}

	@Test
	void registeredRelativeEvidenceIsCanonicalizedWhenClientSendsAbsoluteUrl() {
		UUID bookingId = createHiredBooking();
		UUID nodeId = inspectionService.createNodes(worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", null, 1))).get(0).id();
		String storedUrl = uploadEvidence(worker.getId(), nodeId, "canonical.jpg");
		Throwable untrustedHost = catchThrowable(() ->
			inspectionService.requestInspection(worker.getId(), nodeId,
				new InspectionSubmissionRequest("请验收",
					List.of("https://evil.example" + storedUrl))));
		assertThat(untrustedHost).isInstanceOfSatisfying(
			BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("INVALID_INSPECTION_PHOTO"));

		inspectionService.requestInspection(worker.getId(), nodeId,
			new InspectionSubmissionRequest("请验收",
				List.of("http://47.109.0.191:8080" + storedUrl)));

		assertThat(inspectionService.getTimeline(worker.getId(), nodeId))
			.singleElement()
			.satisfies(event -> assertThat(event.photos()).containsExactly(storedUrl));
	}

	@Test
	void requestAndDecisionRejectNodeThatDoesNotMatchBookingTrade() {
		UUID bookingId = createHiredBooking();
		InspectionNode staleCrossTrade = nodeRepository.saveAndFlush(
			InspectionNode.create(bookingId, "油漆验收", "历史错误节点", 9));

		Throwable requestError = catchThrowable(() ->
			inspectionService.requestInspection(worker.getId(), staleCrossTrade.getId()));
		assertThat(requestError).isInstanceOfSatisfying(BusinessException.class, ex ->
			assertThat(ex.code()).isEqualTo("INSPECTION_NODE_TRADE_MISMATCH"));

		ReflectionTestUtils.setField(staleCrossTrade, "status",
			InspectionNodeStatus.INSPECTING);
		nodeRepository.saveAndFlush(staleCrossTrade);
		Throwable inspectError = catchThrowable(() -> inspectionService.inspect(
			owner.getId(), staleCrossTrade.getId(),
			new InspectRequest(InspectionResult.PASS, "不应通过", List.of())));
		assertThat(inspectError).isInstanceOfSatisfying(BusinessException.class, ex ->
			assertThat(ex.code()).isEqualTo("INSPECTION_NODE_TRADE_MISMATCH"));
	}

	@Test
	void concurrentPassesOnDifferentNodesAlwaysCompleteBooking() throws Exception {
		UUID bookingId = createHiredBooking();
		List<InspectionNodeResponse> nodes = inspectionService.createNodes(
			worker.getId(), bookingId, List.of(
				new CreateNodeRequest("木工基层验收", null, 1),
				new CreateNodeRequest("木工收口验收", null, 2)));
		for (InspectionNodeResponse node : nodes) {
			inspectionService.requestInspection(worker.getId(), node.id());
		}

		ExecutorService executor = Executors.newFixedThreadPool(2);
		CountDownLatch ready = new CountDownLatch(2);
		CountDownLatch start = new CountDownLatch(1);
		try {
			List<Future<InspectionRecordResponse>> results = nodes.stream()
				.map(node -> executor.submit(() -> {
					ready.countDown();
					start.await(5, TimeUnit.SECONDS);
					return inspectionService.inspect(owner.getId(), node.id(),
						new InspectRequest(InspectionResult.PASS, "通过", List.of()));
				}))
				.toList();
			assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
			start.countDown();
			for (Future<InspectionRecordResponse> result : results) {
				assertThat(result.get(10, TimeUnit.SECONDS).result())
					.isEqualTo(InspectionResult.PASS);
			}
		} finally {
			executor.shutdownNow();
		}

		assertThat(bookings.findById(bookingId).orElseThrow().getStatus())
			.isEqualTo(BookingStatus.COMPLETED);
	}

	@Test
	void crossTradeAndDuplicateInspectionNodesAreRejected() {
		UUID bookingId = createHiredBooking();

		Throwable crossTrade = catchThrowable(() -> inspectionService.createNodes(
			worker.getId(), bookingId,
			List.of(new CreateNodeRequest("水电验收", null, 1))));
		assertThat(crossTrade).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("INSPECTION_NODE_TRADE_MISMATCH");
		});

		inspectionService.createNodes(worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", null, 1)));
		Throwable duplicate = catchThrowable(() -> inspectionService.createNodes(
			worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", "重复", 2))));
		assertThat(duplicate).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(409);
			assertThat(ex.code()).isEqualTo("DUPLICATE_INSPECTION_NODE");
		});
	}

	@Test
	void concurrentNodeCreationDoesNotCreateNewDuplicateNames() throws Exception {
		UUID bookingId = createHiredBooking();
		ExecutorService executor = Executors.newFixedThreadPool(2);
		CountDownLatch ready = new CountDownLatch(2);
		CountDownLatch start = new CountDownLatch(1);
		try {
			java.util.concurrent.Callable<Object> create = () -> {
				ready.countDown();
				start.await(5, TimeUnit.SECONDS);
				try {
					return inspectionService.createNodes(worker.getId(), bookingId,
						List.of(new CreateNodeRequest("木工并发验收", null, 1)));
				} catch (Throwable error) {
					return error;
				}
			};
			Future<Object> first = executor.submit(create);
			Future<Object> second = executor.submit(create);
			assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
			start.countDown();

			List<Object> results = List.of(
				first.get(10, TimeUnit.SECONDS),
				second.get(10, TimeUnit.SECONDS));
			assertThat(results.stream().filter(List.class::isInstance).count())
				.as("concurrent create results: %s", results)
				.isEqualTo(1);
			assertThat(results.stream()
				.filter(BusinessException.class::isInstance).count()).isEqualTo(1);
		} finally {
			executor.shutdownNow();
		}

		assertThat(nodeRepository.findByBookingIdOrderBySortOrderAsc(bookingId))
			.filteredOn(node -> node.getName().equals("木工并发验收"))
			.hasSize(1);
	}

	@Test
	void passingAllCurrentTradeNodesCompletesTheBooking() {
		UUID bookingId = createHiredBooking();
		List<InspectionNodeResponse> nodes = inspectionService.createNodes(
			worker.getId(), bookingId, List.of(
				new CreateNodeRequest("木工基层验收", "检查基层", 1),
				new CreateNodeRequest("木工收口验收", "检查收口", 2)));
		nodeRepository.saveAndFlush(InspectionNode.create(
			bookingId, "油漆验收", "历史无关节点", 3));

		inspectionService.requestInspection(worker.getId(), nodes.get(0).id());
		inspectionService.inspect(owner.getId(), nodes.get(0).id(),
			new InspectRequest(InspectionResult.PASS, "基层通过", null));

		assertThat(bookings.findById(bookingId).orElseThrow().getStatus().name())
			.isEqualTo("HIRED");

		inspectionService.requestInspection(worker.getId(), nodes.get(1).id());
		inspectionService.inspect(owner.getId(), nodes.get(1).id(),
			new InspectRequest(InspectionResult.PASS, "收口通过", null));

		assertThat(bookings.findById(bookingId).orElseThrow().getStatus().name())
			.isEqualTo("COMPLETED");
	}

	@Test
	void failedCurrentTradeInspectionKeepsTheBookingInProgress() {
		UUID bookingId = createHiredBooking();
		InspectionNodeResponse node = inspectionService.createNodes(
			worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", "检查柜体", 1))).get(0);

		inspectionService.requestInspection(worker.getId(), node.id());
		inspectionService.inspect(owner.getId(), node.id(),
			new InspectRequest(InspectionResult.FAIL, "需要整改", null));

		assertThat(bookings.findById(bookingId).orElseThrow().getStatus().name())
			.isEqualTo("HIRED");
	}

	@Test
	void failThenReinspectCreatesNewVersion() {
		UUID bookingId = createHiredBooking();

		inspectionService.createNodes(worker.getId(), bookingId, List.of(
			new CreateNodeRequest("木工验收", "检查木作质量", 1)));

		UUID nodeId = inspectionService.getNodes(owner.getId(), bookingId).get(0).id();

		// Worker requests inspection
		inspectionService.requestInspection(worker.getId(), nodeId);

		// Owner fails
		inspectionService.inspect(owner.getId(), nodeId,
			new InspectRequest(InspectionResult.FAIL, "线路不整齐，需整改", null));

		InspectionNodeResponse node = inspectionService.getNodes(
			owner.getId(), bookingId).get(0);
		assertThat(node.status()).isEqualTo(InspectionNodeStatus.FAILED);

		// Worker fixes and re-requests
		inspectionService.requestInspection(worker.getId(), nodeId);
		node = inspectionService.getNodes(owner.getId(), bookingId).get(0);
		assertThat(node.status()).isEqualTo(InspectionNodeStatus.INSPECTING);

		// Owner passes on second inspection
		inspectionService.inspect(owner.getId(), nodeId,
			new InspectRequest(InspectionResult.PASS, "整改后通过", null));

		node = inspectionService.getNodes(owner.getId(), bookingId).get(0);
		assertThat(node.status()).isEqualTo(InspectionNodeStatus.PASSED);

		// Records history has two versions
		List<InspectionRecordResponse> records = inspectionService.getRecords(
			owner.getId(), nodeId);
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
			new CreateNodeRequest("木工验收", null, 1)));

		UUID nodeId = inspectionService.getNodes(owner.getId(), bookingId).get(0).id();

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
			new CreateNodeRequest("木工验收", null, 1)));

		UUID nodeId = inspectionService.getNodes(owner.getId(), bookingId).get(0).id();
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
			new CreateNodeRequest("木工验收", null, 1)));

		UUID nodeId = inspectionService.getNodes(owner.getId(), bookingId).get(0).id();

		Throwable error = catchThrowable(() ->
			inspectionService.requestInspection(owner.getId(), nodeId));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(403);
			assertThat(ex.code()).isEqualTo("NOT_WORKER");
		});
	}

	@Test
	void requestInspectionByDifferentWorkerFails() {
		UUID bookingId = createHiredBooking();
		UUID nodeId = inspectionService.createNodes(worker.getId(), bookingId,
			List.of(new CreateNodeRequest("木工验收", null, 1))).get(0).id();
		User differentWorker = createUser("13800138223", UserRole.WORKER);

		Throwable error = catchThrowable(() ->
			inspectionService.requestInspection(differentWorker.getId(), nodeId));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(403);
			assertThat(ex.code()).isEqualTo("NOT_WORKER");
		});
	}

	@Test
	void unrelatedUserCannotReadInspectionNodes() {
		UUID bookingId = createHiredBooking();
		User unrelated = createUser("13800138222", UserRole.OWNER);

		Throwable error = catchThrowable(() ->
			inspectionService.getNodes(unrelated.getId(), bookingId));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status()).isEqualTo(org.springframework.http.HttpStatus.NOT_FOUND);
			assertThat(ex.code()).isEqualTo("BOOKING_NOT_FOUND");
		});
	}

	private UUID createHiredBooking() {
		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "测试木工")).getId();

		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker.getId(), "李师傅"));
		ReflectionTestUtils.setField(booking, "status",
			com.zhidi.server.booking.BookingStatus.HIRED);
		booking = bookings.saveAndFlush(booking);
		return booking.getId();
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}

	private String uploadEvidence(UUID userId, UUID nodeId, String filename) {
		return inspectionService.uploadEvidence(userId, nodeId,
			new MockMultipartFile("file", filename, "image/jpeg",
				("evidence-" + filename).getBytes())).url();
	}
}
