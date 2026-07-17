package com.zhidi.server;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhidi.server.auth.AuthService;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingService;
import com.zhidi.server.dailyreport.DailyReportRepository;
import com.zhidi.server.quote.QuoteRepository;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.workercase.WorkerCaseRepository;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.worker.WorkerProfileRepository;
import com.zhidi.server.auth.SmsVerificationCodeRepository;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.owner.OwnerProfileService;
import com.zhidi.server.worker.WorkerProfileService;
import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.ResponseEntity;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@SpringBootTest(properties = {
	"spring.autoconfigure.exclude="
		+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
})
@AutoConfigureMockMvc
@Import(SmokeApiTest.ValidationProbeController.class)
class SmokeApiTest {
	private static final UUID USER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000088");

	@Autowired
	MockMvc mvc;

	@MockitoBean
	AuthService authService;

	@MockitoBean
	OwnerProfileService ownerProfileService;

	@MockitoBean
	WorkerProfileService workerProfileService;

	@MockitoBean
	BookingService bookingService;

	@MockitoBean
	DailyReportRepository dailyReports;

	@MockitoBean
	BookingRepository bookingRepository;

	@MockitoBean
	QuoteRepository quotes;

	@MockitoBean
	ServiceRequestRepository serviceRequests;

	@MockitoBean
	WorkerCaseRepository workerCases;

	@MockitoBean
	OwnerProfileRepository ownerProfiles;

	@MockitoBean
	WorkerProfileRepository workerProfiles;

	@MockitoBean
	SmsVerificationCodeRepository smsCodes;

	@MockitoBean
	OperationLogRepository operationLogs;

	@Autowired
	JwtTokenService tokens;

	@MockitoBean
	UserRepository users;

	@Test
	void healthResponseCarriesTraceId() throws Exception {
		mvc.perform(get("/actuator/health").header("X-Trace-Id", "test-trace"))
			.andExpect(status().isOk())
			.andExpect(header().string("X-Trace-Id", "test-trace"));
	}

	@Test
	void validationErrorsUseTheSharedEnvelope() throws Exception {
		User user = mock(User.class);
		when(user.getPhone()).thenReturn("13800138000");
		when(user.getStatus()).thenReturn(UserStatus.ACTIVE);
		when(user.getRoles()).thenReturn(Set.of(UserRole.OWNER));
		when(users.findById(USER_ID)).thenReturn(Optional.of(user));
		String token = tokens.issue(USER_ID, "13800138000", Set.of(UserRole.OWNER))
			.accessToken();

		mvc.perform(post("/api/v1/test/validation")
				.header("Authorization", "Bearer " + token)
				.contentType(APPLICATION_JSON)
				.content("{}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
			.andExpect(jsonPath("$.traceId").isNotEmpty());
	}

	@RestController
	static class ValidationProbeController {

		@PostMapping("/api/v1/test/validation")
		ResponseEntity<Void> validate(@Valid @RequestBody ValidationProbeRequest request) {
			return ResponseEntity.noContent().build();
		}
	}

	record ValidationProbeRequest(@NotBlank String name) {
	}
}
