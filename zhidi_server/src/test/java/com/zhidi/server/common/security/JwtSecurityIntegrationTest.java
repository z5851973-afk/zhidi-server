package com.zhidi.server.common.security;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.auth.AuthService;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.owner.OwnerProfileService;
import com.zhidi.server.worker.WorkerProfileService;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootTest(properties = {
	"spring.autoconfigure.exclude="
		+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration",
	"auth.jwt.secret=integration-test-secret-at-least-thirty-two-bytes-long"
})
@AutoConfigureMockMvc
@Import(JwtSecurityIntegrationTest.ProbeController.class)
class JwtSecurityIntegrationTest {

	private static final UUID USER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000099");
	private static final String PHONE = "13800138000";

	@Autowired
	MockMvc mvc;

	@Autowired
	JwtTokenService tokens;

	@MockitoBean
	UserRepository users;

	@MockitoBean
	AuthService authService;

	@MockitoBean
	OwnerProfileService ownerProfileService;

	@MockitoBean
	WorkerProfileService workerProfileService;

	@Test
	void missingTokenReturnsUnifiedAuthenticationErrorWithTraceId() throws Exception {
		mvc.perform(get("/api/v1/test/current-user").header("X-Trace-Id", "missing-trace"))
			.andExpect(status().isUnauthorized())
			.andExpect(header().string("X-Trace-Id", "missing-trace"))
			.andExpect(jsonPath("$.code").value("AUTHENTICATION_REQUIRED"))
			.andExpect(jsonPath("$.traceId").value("missing-trace"));
	}

	@Test
	void validTokenUsesDatabaseIdentityAndRoles() throws Exception {
		User storedUser = user(PHONE, UserStatus.ACTIVE, Set.of(UserRole.OWNER));
		when(users.findById(USER_ID)).thenReturn(Optional.of(storedUser));

		mvc.perform(get("/api/v1/test/current-user").header("Authorization", bearer(validToken())))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.userId").value(USER_ID.toString()))
			.andExpect(jsonPath("$.phone").value(PHONE))
			.andExpect(jsonPath("$.roles[0]").value("OWNER"));
	}

	@Test
	void databaseRolesOverrideRolesStoredInToken() throws Exception {
		User storedUser = user(PHONE, UserStatus.ACTIVE, Set.of(UserRole.WORKER));
		when(users.findById(USER_ID)).thenReturn(Optional.of(storedUser));

		mvc.perform(get("/api/v1/test/owner-only")
				.header("Authorization", bearer(validToken()))
				.header("X-Trace-Id", "denied-trace"))
			.andExpect(status().isForbidden())
			.andExpect(header().string("X-Trace-Id", "denied-trace"))
			.andExpect(jsonPath("$.code").value("ACCESS_DENIED"))
			.andExpect(jsonPath("$.traceId").value("denied-trace"));
	}

	@Test
	void disabledUserIsRejected() throws Exception {
		User storedUser = user(PHONE, UserStatus.DISABLED, Set.of(UserRole.OWNER));
		when(users.findById(USER_ID)).thenReturn(Optional.of(storedUser));

		mvc.perform(get("/api/v1/test/current-user").header("Authorization", bearer(validToken())))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("ACCOUNT_DISABLED"));
	}

	@Test
	void tamperedTokenIsRejected() throws Exception {
		String token = validToken();
		String tampered = token.substring(0, token.length() - 1)
			+ (token.endsWith("a") ? "b" : "a");

		mvc.perform(get("/api/v1/test/current-user").header("Authorization", bearer(tampered)))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("TOKEN_INVALID"));
	}

	@Test
	void expiredTokenIsRejected() throws Exception {
		JwtTokenService expiredIssuer = new JwtTokenService(
			"integration-test-secret-at-least-thirty-two-bytes-long",
			Duration.ofMinutes(1),
			Clock.fixed(Instant.parse("2020-01-01T00:00:00Z"), ZoneOffset.UTC));
		String expired = expiredIssuer.issue(USER_ID, PHONE, Set.of(UserRole.OWNER)).accessToken();

		mvc.perform(get("/api/v1/test/current-user").header("Authorization", bearer(expired)))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("TOKEN_EXPIRED"));
	}

	@Test
	void badTokenDoesNotBlockPublicAuthenticationPath() throws Exception {
		mvc.perform(get("/api/v1/auth/test-public").header("Authorization", "Bearer bad-token"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.publicPath").value(true));
	}

	private String validToken() {
		return tokens.issue(USER_ID, "19999999999", Set.of(UserRole.OWNER)).accessToken();
	}

	private String bearer(String token) {
		return "Bearer " + token;
	}

	private User user(String phone, UserStatus status, Set<UserRole> roles) {
		User user = mock(User.class);
		when(user.getPhone()).thenReturn(phone);
		when(user.getStatus()).thenReturn(status);
		when(user.getRoles()).thenReturn(roles);
		return user;
	}

	@RestController
	static class ProbeController {

		@GetMapping("/api/v1/test/current-user")
		CurrentUserPrincipal currentUser(Authentication authentication) {
			return (CurrentUserPrincipal) authentication.getPrincipal();
		}

		@PreAuthorize("hasRole('OWNER')")
		@GetMapping("/api/v1/test/owner-only")
		void ownerOnly() {
		}

		@GetMapping("/api/v1/auth/test-public")
		PublicResponse publicPath() {
			return new PublicResponse(true);
		}
	}

	record PublicResponse(boolean publicPath) {
	}
}
