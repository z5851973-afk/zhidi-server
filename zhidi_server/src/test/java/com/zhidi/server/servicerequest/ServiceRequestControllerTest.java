package com.zhidi.server.servicerequest;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.auth.AuthService;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.auth.SmsVerificationCodeRepository;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingResponse;
import com.zhidi.server.booking.BookingService;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.dailyreport.DailyReportRepository;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.owner.OwnerProfileService;
import com.zhidi.server.quote.QuoteRepository;
import com.zhidi.server.worker.WorkerProfileRepository;
import com.zhidi.server.worker.WorkerProfileService;
import com.zhidi.server.workercase.WorkerCaseRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@org.springframework.context.annotation.Import(com.zhidi.server.support.RoadmapPersistenceTestConfig.class)
@SpringBootTest(properties = {
	"spring.autoconfigure.exclude="
		+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration",
	"auth.jwt.secret=service-request-controller-test-secret-12345678"
})
@AutoConfigureMockMvc
class ServiceRequestControllerTest {

	private static final UUID OWNER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000201");
	private static final UUID WORKER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000202");
	private static final UUID REQUEST_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000203");
	private static final UUID WORKER_USER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000204");
	private static final UUID BOOKING_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000205");

	@Autowired
	MockMvc mvc;

	@Autowired
	JwtTokenService tokens;

	@MockitoBean
	ServiceRequestService service;

	@MockitoBean
	BookingService bookingService;

	@MockitoBean
	BookingRepository bookingRepository;

	@MockitoBean
	ServiceRequestRepository serviceRequestRepository;

	@MockitoBean
	OwnerProfileService ownerProfileService;

	@MockitoBean
	WorkerProfileService workerProfileService;

	@MockitoBean
	UserRepository users;

	@MockitoBean
	AuthService authService;

	@MockitoBean
	DailyReportRepository dailyReports;

	@MockitoBean
	QuoteRepository quotes;

	@MockitoBean
	WorkerProfileRepository workerProfiles;

	@MockitoBean
	OwnerProfileRepository ownerProfiles;

	@MockitoBean
	WorkerCaseRepository workerCases;

	@MockitoBean
	SmsVerificationCodeRepository smsCodes;

	@MockitoBean
	OperationLogRepository operationLogs;

	@Test
	void ownerCreatesServiceRequest() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(service.createRequest(any(), any())).thenReturn(singleResponse());

		mvc.perform(post("/api/v1/owners/me/service-requests")
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER))
				.contentType(APPLICATION_JSON)
				.content("""
					{"trade":"水电","serviceCity":"成都","serviceAddress":"高新区 1 号",
					 "areaSqm":98.5,"bedroomCount":3,"livingRoomCount":2,
					 "kitchenCount":1,"bathroomCount":2,
					 "remark":"旧房水电改造"}
					"""))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.id").value(REQUEST_ID.toString()))
			.andExpect(jsonPath("$.data.trade").value("水电"))
			.andExpect(jsonPath("$.data.areaSqm").value(98.5))
			.andExpect(jsonPath("$.data.bedroomCount").value(3))
			.andExpect(jsonPath("$.data.livingRoomCount").value(2))
			.andExpect(jsonPath("$.data.kitchenCount").value(1))
			.andExpect(jsonPath("$.data.bathroomCount").value(2))
			.andExpect(jsonPath("$.data.status").value("OPEN"));

		verify(service).createRequest(eq(OWNER_ID),
			eq(new ServiceRequestCreateRequest("水电", "成都", "高新区 1 号",
				new BigDecimal("98.5"), (short) 3, (short) 2, (short) 1,
				(short) 2, "旧房水电改造")));
	}

	@Test
	void workerCannotCreateServiceRequest() throws Exception {
		givenDatabaseUser(WORKER_ID, "16600000002", UserRole.WORKER);

		mvc.perform(post("/api/v1/owners/me/service-requests")
				.header("Authorization", bearerToken(WORKER_ID, UserRole.WORKER))
				.contentType(APPLICATION_JSON)
				.content("""
					{"trade":"水电","serviceCity":"成都","areaSqm":98.5,
					 "bedroomCount":3,"livingRoomCount":2,"kitchenCount":1,
					 "bathroomCount":2}
					"""))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("ACCESS_DENIED"));

		verify(service, never()).createRequest(any(), any());
	}

	@Test
	void ownerListsOwnServiceRequests() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(service.listOwnerRequests(OWNER_ID)).thenReturn(List.of(singleResponse()));

		mvc.perform(get("/api/v1/owners/me/service-requests")
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data[0].id").value(REQUEST_ID.toString()))
			.andExpect(jsonPath("$.data[0].status").value("OPEN"));

		verify(service).listOwnerRequests(OWNER_ID);
	}

	@Test
	void ownerAddsCandidateToRequest() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(service.addCandidate(any(), any(), any())).thenReturn(responseWithCandidates());

		mvc.perform(post("/api/v1/owners/me/service-requests/{requestId}/candidates",
					REQUEST_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER))
				.contentType(APPLICATION_JSON)
				.content("{\"workerUserId\":\"" + WORKER_USER_ID + "\"}"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.candidates[0].workerUserId")
				.value(WORKER_USER_ID.toString()));

		verify(service).addCandidate(eq(OWNER_ID), eq(REQUEST_ID),
			eq(new CandidateCreateRequest(WORKER_USER_ID)));
	}

	@Test
	void ownerRemovesCandidateFromRequest() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(service.removeCandidate(OWNER_ID, REQUEST_ID, BOOKING_ID))
			.thenReturn(singleResponse());

		mvc.perform(post(
				"/api/v1/owners/me/service-requests/{requestId}/candidates/{bookingId}/remove",
				REQUEST_ID, BOOKING_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.activeCandidateCount").value(0))
			.andExpect(jsonPath("$.data.availableCandidateSlots").value(3));

		verify(service).removeCandidate(OWNER_ID, REQUEST_ID, BOOKING_ID);
	}

	@Test
	void ownerAtomicallyReplacesCandidate() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(service.replaceCandidate(any(), any(), any(), any()))
			.thenReturn(responseWithCandidates());

		mvc.perform(post(
				"/api/v1/owners/me/service-requests/{requestId}/candidates/{bookingId}/replace",
				REQUEST_ID, BOOKING_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER))
				.contentType(APPLICATION_JSON)
				.content("{\"workerUserId\":\"" + WORKER_USER_ID + "\"}"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"));

		verify(service).replaceCandidate(eq(OWNER_ID), eq(REQUEST_ID),
			eq(BOOKING_ID), eq(new CandidateCreateRequest(WORKER_USER_ID)));
	}

	@Test
	void ownerReopensCancelledRequestAsNewRequest() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(service.reopenRequest(OWNER_ID, REQUEST_ID)).thenReturn(singleResponse());

		mvc.perform(post(
				"/api/v1/owners/me/service-requests/{requestId}/reopen", REQUEST_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.status").value("OPEN"));

		verify(service).reopenRequest(OWNER_ID, REQUEST_ID);
	}

	@Test
	void ownerCancelsServiceRequest() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(service.cancelRequest(OWNER_ID, REQUEST_ID))
			.thenReturn(responseWithStatus(ServiceRequestStatus.CANCELLED));

		mvc.perform(post("/api/v1/owners/me/service-requests/{requestId}/cancel",
					REQUEST_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.status").value("CANCELLED"));

		verify(service).cancelRequest(OWNER_ID, REQUEST_ID);
	}

	@Test
	void invalidCreateRequestReturnsValidationError() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);

		mvc.perform(post("/api/v1/owners/me/service-requests")
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER))
				.contentType(APPLICATION_JSON)
				.content("{\"remark\":\"" + "x".repeat(501) + "\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		verify(service, never()).createRequest(any(), any());
	}

	@ParameterizedTest
	@ValueSource(strings = {
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"bedroomCount\":3,\"livingRoomCount\":2,\"kitchenCount\":1,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"livingRoomCount\":2,\"kitchenCount\":1,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"bedroomCount\":3,\"kitchenCount\":1,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"bedroomCount\":3,\"livingRoomCount\":2,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"bedroomCount\":3,\"livingRoomCount\":2,\"kitchenCount\":1}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":0,\"bedroomCount\":3,\"livingRoomCount\":2,\"kitchenCount\":1,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":10000,\"bedroomCount\":3,\"livingRoomCount\":2,\"kitchenCount\":1,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.555,\"bedroomCount\":3,\"livingRoomCount\":2,\"kitchenCount\":1,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"bedroomCount\":0,\"livingRoomCount\":2,\"kitchenCount\":1,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"bedroomCount\":21,\"livingRoomCount\":2,\"kitchenCount\":1,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"bedroomCount\":3,\"livingRoomCount\":11,\"kitchenCount\":1,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"bedroomCount\":3,\"livingRoomCount\":2,\"kitchenCount\":11,\"bathroomCount\":2}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"bedroomCount\":3,\"livingRoomCount\":2,\"kitchenCount\":1,\"bathroomCount\":0}",
		"{\"trade\":\"水电\",\"serviceCity\":\"成都\",\"areaSqm\":98.5,\"bedroomCount\":3,\"livingRoomCount\":2,\"kitchenCount\":1,\"bathroomCount\":21}"
	})
	void rejectsIncompleteOrOutOfRangeHouseInfo(String body) throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);

		mvc.perform(post("/api/v1/owners/me/service-requests")
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER))
				.contentType(APPLICATION_JSON)
				.content(body))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		verify(service, never()).createRequest(any(), any());
	}

	private void givenDatabaseUser(UUID userId, String phone, UserRole role) {
		User user = Mockito.mock(User.class);
		when(user.getPhone()).thenReturn(phone);
		when(user.getStatus()).thenReturn(UserStatus.ACTIVE);
		when(user.getRoles()).thenReturn(Set.of(role));
		when(users.findById(userId)).thenReturn(Optional.of(user));
	}

	private String bearerToken(UUID userId, UserRole role) {
		return "Bearer " + tokens.issue(userId, "19999999999", Set.of(role)).accessToken();
	}

	private ServiceRequestResponse singleResponse() {
		return responseWithStatus(ServiceRequestStatus.OPEN);
	}

	private ServiceRequestResponse responseWithStatus(ServiceRequestStatus status) {
		Instant now = Instant.parse("2026-07-17T10:00:00Z");
		return new ServiceRequestResponse(REQUEST_ID, OWNER_ID,
			"水电", "成都", "高新区 1 号", "旧房水电改造",
			new BigDecimal("98.5"), (short) 3, (short) 2, (short) 1, (short) 2,
			status, List.of(), now, now, 0, 3,
			status == ServiceRequestStatus.OPEN
				|| status == ServiceRequestStatus.COMPARING);
	}

	private ServiceRequestResponse responseWithCandidates() {
		Instant now = Instant.parse("2026-07-17T10:00:00Z");
		BookingResponse candidate = new BookingResponse(
			UUID.randomUUID(), REQUEST_ID,
			OWNER_ID, "林业主", "16600000001",
			WORKER_USER_ID, "张师傅",
			"水电", "成都", "高新区 1 号", "旧房水电改造",
			new BigDecimal("98.5"), (short) 3, (short) 2, (short) 1, (short) 2,
			BookingStatus.PENDING,
			null, null, null, false, false, null, null, null, null, now, now,
			true, true);
		return new ServiceRequestResponse(REQUEST_ID, OWNER_ID,
			"水电", "成都", "高新区 1 号", "旧房水电改造",
			new BigDecimal("98.5"), (short) 3, (short) 2, (short) 1, (short) 2,
			ServiceRequestStatus.COMPARING, List.of(candidate), now, now,
			1, 2, true);
	}
}
