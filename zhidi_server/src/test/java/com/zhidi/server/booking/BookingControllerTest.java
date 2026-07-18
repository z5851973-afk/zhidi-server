package com.zhidi.server.booking;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.auth.AuthService;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.auth.SmsVerificationCodeRepository;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.dailyreport.DailyReportRepository;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.owner.OwnerProfileService;
import com.zhidi.server.quote.QuoteRepository;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.worker.WorkerProfileRepository;
import com.zhidi.server.worker.WorkerProfileService;
import com.zhidi.server.workercase.WorkerCaseRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
	"spring.autoconfigure.exclude="
		+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration",
	"auth.jwt.secret=booking-controller-test-secret-at-least-thirty-two-bytes"
})
@AutoConfigureMockMvc
class BookingControllerTest {

	private static final UUID OWNER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000201");
	private static final UUID WORKER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000202");
	private static final UUID BOOKING_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000203");

	@Autowired
	MockMvc mvc;

	@Autowired
	JwtTokenService tokens;

	@MockitoBean
	BookingService bookingService;

	@MockitoBean
	BookingRepository bookingRepository;

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
	ServiceRequestRepository serviceRequests;

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

	@MockitoBean
	VisitProposalRepository visitProposals;

	@Test
	void ownerCreatesBookingUsingPrincipalIdentity() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(bookingService.create(any(), any())).thenReturn(response(BookingStatus.PENDING));

		mvc.perform(post("/api/v1/bookings")
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER))
				.contentType(APPLICATION_JSON)
				.content("""
					{"workerUserId":"01904f24-3f5b-7000-8000-000000000202",
					 "trade":"泥工","serviceCity":"杭州","serviceAddress":"西湖区",
					 "remark":"厨房墙砖铺贴"}
					"""))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.id").value(BOOKING_ID.toString()))
			.andExpect(jsonPath("$.data.status").value("PENDING"))
			.andExpect(jsonPath("$.data.ownerName").value("林业主"))
			.andExpect(jsonPath("$.data.ownerPhone").value("16600000001"))
			.andExpect(jsonPath("$.data.workerName").value("周师傅"));

		verify(bookingService).create(OWNER_ID, new BookingRequest(WORKER_ID,
			"泥工", "杭州", "西湖区", "厨房墙砖铺贴"));
	}

	@Test
	void workerCannotCreateOwnerBooking() throws Exception {
		givenDatabaseUser(WORKER_ID, "16600000002", UserRole.WORKER);

		mvc.perform(post("/api/v1/bookings")
				.header("Authorization", bearerToken(WORKER_ID, UserRole.WORKER))
				.contentType(APPLICATION_JSON)
				.content("{\"workerUserId\":\"" + WORKER_ID + "\"}"))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("ACCESS_DENIED"));

		verify(bookingService, never()).create(any(), any());
	}

	@Test
	void ownerListsOwnBookings() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(bookingService.listForOwner(OWNER_ID)).thenReturn(List.of(response(BookingStatus.PENDING)));

		mvc.perform(get("/api/v1/owners/me/bookings")
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data[0].id").value(BOOKING_ID.toString()));

		verify(bookingService).listForOwner(OWNER_ID);
	}

	@Test
	void workerListsAndAcceptsOwnBookings() throws Exception {
		givenDatabaseUser(WORKER_ID, "16600000002", UserRole.WORKER);
		when(bookingService.listForWorker(WORKER_ID)).thenReturn(List.of(response(BookingStatus.PENDING)));
		when(bookingService.accept(WORKER_ID, BOOKING_ID)).thenReturn(response(BookingStatus.ACCEPTED));

		mvc.perform(get("/api/v1/workers/me/bookings")
				.header("Authorization", bearerToken(WORKER_ID, UserRole.WORKER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data[0].status").value("PENDING"));

		mvc.perform(post("/api/v1/workers/me/bookings/{id}/accept", BOOKING_ID)
				.header("Authorization", bearerToken(WORKER_ID, UserRole.WORKER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.status").value("ACCEPTED"));

		verify(bookingService).listForWorker(WORKER_ID);
		verify(bookingService).accept(WORKER_ID, BOOKING_ID);
	}

	@Test
	void invalidCreateRequestReturnsValidationError() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);

		mvc.perform(post("/api/v1/bookings")
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER))
				.contentType(APPLICATION_JSON)
				.content("{\"workerUserId\":null,\"remark\":\"" + "x".repeat(501) + "\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		verify(bookingService, never()).create(any(), any());
	}

	@Test
	void ownerCancelBlankReasonReturnsValidationError() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);

		mvc.perform(post("/api/v1/owners/me/bookings/{id}/cancel", BOOKING_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER))
				.contentType(APPLICATION_JSON)
				.content("{\"reason\":\"\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		verify(bookingService, never()).ownerCancel(any(), any(), any());
	}

	@Test
	void workerCancelBlankReasonReturnsValidationError() throws Exception {
		givenDatabaseUser(WORKER_ID, "16600000002", UserRole.WORKER);

		mvc.perform(post("/api/v1/workers/me/bookings/{id}/cancel", BOOKING_ID)
				.header("Authorization", bearerToken(WORKER_ID, UserRole.WORKER))
				.contentType(APPLICATION_JSON)
				.content("{\"reason\":\"   \"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		verify(bookingService, never()).workerCancel(any(), any(), any());
	}

	@Test
	void workerProposesVisitTime() throws Exception {
		givenDatabaseUser(WORKER_ID, "16600000002", UserRole.WORKER);
		when(bookingService.proposeVisit(any(), any(), any()))
			.thenReturn(response(BookingStatus.VISIT_PROPOSED));

		mvc.perform(put("/api/v1/bookings/{id}/visit-proposal", BOOKING_ID)
				.header("Authorization", bearerToken(WORKER_ID, UserRole.WORKER))
				.contentType(APPLICATION_JSON)
				.content("{\"proposedTime\":\"2026-07-18T09:00:00Z\"}"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.status").value("VISIT_PROPOSED"));
	}

	@Test
	void ownerAcceptsVisit() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(bookingService.acceptVisit(OWNER_ID, BOOKING_ID))
			.thenReturn(response(BookingStatus.VISIT_SCHEDULED));

		mvc.perform(put("/api/v1/owners/me/bookings/{id}/accept-visit", BOOKING_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.status").value("VISIT_SCHEDULED"));
	}

	@Test
	void ownerRejectsVisit() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		when(bookingService.rejectVisit(OWNER_ID, BOOKING_ID, "时间不合适"))
			.thenReturn(response(BookingStatus.ACCEPTED));

		mvc.perform(put("/api/v1/owners/me/bookings/{id}/reject-visit", BOOKING_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER))
				.contentType(APPLICATION_JSON)
				.content("{\"reason\":\"时间不合适\"}"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.status").value("ACCEPTED"));
	}

	@Test
	void workerArrives() throws Exception {
		givenDatabaseUser(WORKER_ID, "16600000002", UserRole.WORKER);
		var resp = response(BookingStatus.ARRIVAL_PENDING);
		when(bookingService.arrive(WORKER_ID, BOOKING_ID, true)).thenReturn(resp);

		mvc.perform(put("/api/v1/workers/me/bookings/{id}/arrive", BOOKING_ID)
				.header("Authorization", bearerToken(WORKER_ID, UserRole.WORKER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.status").value("ARRIVAL_PENDING"));
	}

	@Test
	void ownerArrives() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		var resp = response(BookingStatus.ON_SITE);
		when(bookingService.arrive(OWNER_ID, BOOKING_ID, false)).thenReturn(resp);

		mvc.perform(put("/api/v1/owners/me/bookings/{id}/arrive", BOOKING_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.status").value("ON_SITE"));
	}

	@Test
	void workerConfirmArrival() throws Exception {
		givenDatabaseUser(WORKER_ID, "16600000002", UserRole.WORKER);
		var resp = response(BookingStatus.ON_SITE);
		when(bookingService.confirmArrival(WORKER_ID, BOOKING_ID, true)).thenReturn(resp);

		mvc.perform(put("/api/v1/workers/me/bookings/{id}/confirm-arrival", BOOKING_ID)
				.header("Authorization", bearerToken(WORKER_ID, UserRole.WORKER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.status").value("ON_SITE"));
	}

	@Test
	void ownerConfirmArrival() throws Exception {
		givenDatabaseUser(OWNER_ID, "16600000001", UserRole.OWNER);
		var resp = response(BookingStatus.ON_SITE);
		when(bookingService.confirmArrival(OWNER_ID, BOOKING_ID, false)).thenReturn(resp);

		mvc.perform(put("/api/v1/owners/me/bookings/{id}/confirm-arrival", BOOKING_ID)
				.header("Authorization", bearerToken(OWNER_ID, UserRole.OWNER)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.status").value("ON_SITE"));
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

	private BookingResponse response(BookingStatus status) {
		Instant now = Instant.parse("2026-07-15T10:00:00Z");
		return new BookingResponse(BOOKING_ID, BOOKING_ID,
			OWNER_ID, "林业主", "16600000001",
			WORKER_ID, "周师傅",
			"泥工", "杭州", "西湖区", "厨房墙砖铺贴", status,
			null, null, null,
			false, false, null, null,
			now, now);
	}
}
