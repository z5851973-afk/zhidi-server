package com.zhidi.server.inspection;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.infrastructure.storage.FileStorageService;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

@SpringBootTest(
	webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
	properties = "zhidi.upload.root=target/test-uploads/inspection-http-smoke")
@ActiveProfiles("test")
class InspectionHttpSmokeTest extends MySqlContainerSupport {

	@Autowired
	TestRestTemplate rest;

	@Autowired
	ObjectMapper objectMapper;

	@Autowired
	JwtTokenService tokens;

	@Autowired
	InspectionNodeRepository nodes;

	@Autowired
	InspectionRecordRepository records;

	@Autowired
	InspectionSubmissionRepository submissions;

	@Autowired
	InspectionEvidenceAssetRepository evidenceAssets;

	@Autowired
	FileStorageService fileStorage;

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
	void seedParticipants() {
		records.deleteAll();
		submissions.deleteAll();
		evidenceAssets.deleteAll();
		nodes.deleteAll();
		bookings.deleteAll();
		serviceRequests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();

		owner = createUser("13800138310", UserRole.OWNER);
		worker = createUser("13800138311", UserRole.WORKER);
		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(),
			"王业主", "成都", "旧房改造", "金牛区", new BigDecimal("96.00")));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(),
			"陈师傅", "成都", "木工", 10, new BigDecimal("520.00"), "木作经验丰富"));
	}

	@AfterEach
	void deleteUploadedEvidenceFiles() {
		evidenceAssets.findAll().forEach(asset ->
			fileStorage.delete(asset.getObjectKey()));
	}

	@Test
	void realHttpFlowSupportsFailureRectificationAndPass() throws Exception {
		UUID bookingId = createHiredBooking();
		String workerToken = token(worker, UserRole.WORKER);
		String ownerToken = token(owner, UserRole.OWNER);

		ResponseEntity<String> created = exchange(
			HttpMethod.POST,
			"/api/v1/bookings/" + bookingId + "/inspection-nodes",
			workerToken,
			List.of(Map.of(
				"name", "木工完工验收",
				"description", "检查柜体与收口",
				"sortOrder", 1)));
		assertThat(created.getStatusCode()).isEqualTo(HttpStatus.OK);
		JsonNode createdData = data(created);
		assertThat(createdData.isArray()).isTrue();
		UUID nodeId = UUID.fromString(createdData.get(0).path("id").asText());
		String workerRoundOne = uploadEvidence(
			workerToken, nodeId, "worker-round-one.jpg");

		ResponseEntity<String> firstRequest = exchange(
			HttpMethod.PUT,
			"/api/v1/inspection-nodes/" + nodeId + "/request-inspection",
			workerToken,
			Map.of("note", "首轮完工，请验收", "photos", List.of(workerRoundOne)));
		assertThat(firstRequest.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(data(firstRequest).path("status").asText()).isEqualTo("INSPECTING");

		JsonNode firstTimeline = timeline(nodeId, ownerToken);
		assertThat(firstTimeline).hasSize(1);
		assertThat(firstTimeline.get(0).path("type").asText())
			.isEqualTo("WORKER_SUBMISSION");
		assertThat(firstTimeline.get(0).path("round").asInt()).isEqualTo(1);
		assertThat(firstTimeline.get(0).path("photos").get(0).asText())
			.isEqualTo(workerRoundOne);
		String ownerFailureEvidence = uploadEvidence(
			ownerToken, nodeId, "owner-failure.jpg");

		ResponseEntity<String> failed = exchange(
			HttpMethod.POST,
			"/api/v1/inspection-nodes/" + nodeId + "/inspect",
			ownerToken,
			Map.of(
				"result", "FAIL",
				"comment", "柜门缝隙需要整改",
				"photos", List.of(ownerFailureEvidence)));
		assertThat(failed.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(data(failed).path("result").asText()).isEqualTo("FAIL");

		String workerRoundTwo = uploadEvidence(
			workerToken, nodeId, "worker-round-two.jpg");
		ResponseEntity<String> resubmitted = exchange(
			HttpMethod.PUT,
			"/api/v1/inspection-nodes/" + nodeId + "/request-inspection",
			workerToken,
			Map.of("note", "已调整柜门缝隙，请复验", "photos", List.of(workerRoundTwo)));
		assertThat(resubmitted.getStatusCode()).isEqualTo(HttpStatus.OK);
		String ownerPassEvidence = uploadEvidence(
			ownerToken, nodeId, "owner-pass.jpg");

		ResponseEntity<String> passed = exchange(
			HttpMethod.POST,
			"/api/v1/inspection-nodes/" + nodeId + "/inspect",
			ownerToken,
			Map.of("result", "PASS", "comment", "复验通过",
				"photos", List.of(ownerPassEvidence)));
		assertThat(passed.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(data(passed).path("version").asInt()).isEqualTo(2);

		JsonNode completedTimeline = timeline(nodeId, ownerToken);
		assertThat(completedTimeline).hasSize(4);
		assertThat(completedTimeline.get(0).path("type").asText())
			.isEqualTo("WORKER_SUBMISSION");
		assertThat(completedTimeline.get(1).path("result").asText()).isEqualTo("FAIL");
		assertThat(completedTimeline.get(2).path("round").asInt()).isEqualTo(2);
		assertThat(completedTimeline.get(3).path("result").asText()).isEqualTo("PASS");
		assertThat(bookings.findById(bookingId).orElseThrow().getStatus())
			.isEqualTo(BookingStatus.COMPLETED);
	}

	private JsonNode timeline(UUID nodeId, String token) throws Exception {
		ResponseEntity<String> response = exchange(
			HttpMethod.GET,
			"/api/v1/inspection-nodes/" + nodeId + "/timeline",
			token,
			null);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		return data(response);
	}

	private String uploadEvidence(String token, UUID nodeId, String filename)
			throws Exception {
		HttpHeaders partHeaders = new HttpHeaders();
		partHeaders.setContentType(MediaType.IMAGE_JPEG);
		partHeaders.setContentDisposition(ContentDisposition.formData()
			.name("file").filename(filename).build());
		ByteArrayResource resource = new ByteArrayResource(
			("jpeg-evidence-" + filename).getBytes()) {
			@Override
			public String getFilename() {
				return filename;
			}
		};
		MultiValueMap<String, Object> parts = new LinkedMultiValueMap<>();
		parts.add("file", new HttpEntity<>(resource, partHeaders));
		HttpHeaders headers = new HttpHeaders();
		headers.setBearerAuth(token);
		headers.setContentType(MediaType.MULTIPART_FORM_DATA);
		ResponseEntity<String> response = rest.exchange(
			"/api/v1/inspection-nodes/" + nodeId + "/evidence",
			HttpMethod.POST,
			new HttpEntity<>(parts, headers),
			String.class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		return data(response).path("url").asText();
	}

	private ResponseEntity<String> exchange(
			HttpMethod method, String path, String accessToken, Object body) {
		HttpHeaders headers = new HttpHeaders();
		headers.setBearerAuth(accessToken);
		if (body != null) {
			headers.setContentType(MediaType.APPLICATION_JSON);
		}
		return rest.exchange(path, method, new HttpEntity<>(body, headers), String.class);
	}

	private JsonNode data(ResponseEntity<String> response) throws Exception {
		JsonNode envelope = objectMapper.readTree(response.getBody());
		assertThat(envelope.path("code").asText()).isEqualTo("OK");
		return envelope.path("data");
	}

	private UUID createHiredBooking() {
		ServiceRequest request = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "成都", "金牛区", "全屋木作改造"));
		Booking booking = Booking.createCandidate(request,
			owner.getId(), "王业主", owner.getPhone(),
			worker.getId(), "陈师傅");
		ReflectionTestUtils.setField(booking, "status", BookingStatus.HIRED);
		return bookings.saveAndFlush(booking).getId();
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}

	private String token(User user, UserRole role) {
		return tokens.issue(user.getId(), user.getPhone(), Set.of(role)).accessToken();
	}
}
