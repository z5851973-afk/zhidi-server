package com.zhidi.server.owner;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.auth.AuthService;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.booking.BookingService;
import com.zhidi.server.worker.WorkerProfileService;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
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
	"auth.jwt.secret=owner-profile-controller-test-secret-at-least-thirty-two-bytes"
})
@AutoConfigureMockMvc
class OwnerProfileControllerTest {

	private static final UUID USER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000002");
	private static final String PHONE = "16600000002";

	@Autowired
	MockMvc mvc;

	@Autowired
	JwtTokenService tokens;

	@MockitoBean
	OwnerProfileService ownerProfileService;

	@MockitoBean
	WorkerProfileService workerProfileService;

	@MockitoBean
	BookingService bookingService;

	@MockitoBean
	UserRepository users;

	@MockitoBean
	AuthService authService;

	@Test
	void missingTokenReturnsUnifiedAuthenticationError() throws Exception {
		mvc.perform(get("/api/v1/owners/me"))
			.andExpect(status().isUnauthorized())
			.andExpect(jsonPath("$.code").value("AUTHENTICATION_REQUIRED"));
	}

	@Test
	void activeDatabaseOwnerCanGetProfileUsingDatabaseIdentity() throws Exception {
		givenDatabaseUser(UserRole.OWNER);
		when(ownerProfileService.get(USER_ID, PHONE)).thenReturn(response());

		mvc.perform(get("/api/v1/owners/me").header("Authorization", bearerToken()))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.userId").value(USER_ID.toString()))
			.andExpect(jsonPath("$.data.phone").value(PHONE))
			.andExpect(jsonPath("$.data.city").value("成都"))
			.andExpect(jsonPath("$.data.profileComplete").value(true));

		verify(ownerProfileService).get(USER_ID, PHONE);
	}

	@Test
	void databaseWorkerIsForbiddenEvenWhenTokenClaimsOwner() throws Exception {
		givenDatabaseUser(UserRole.WORKER);

		mvc.perform(get("/api/v1/owners/me").header("Authorization", bearerToken()))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("ACCESS_DENIED"));

		verify(ownerProfileService, never()).get(any(), any());
	}

	@Test
	void validPutUpdatesAllEditableFieldsUsingPrincipalIdentity() throws Exception {
		givenDatabaseUser(UserRole.OWNER);
		when(ownerProfileService.update(any(), any(), any())).thenReturn(response());

		mvc.perform(put("/api/v1/owners/me")
				.header("Authorization", bearerToken())
				.contentType(APPLICATION_JSON)
				.content("""
					{"userId":"00000000-0000-0000-0000-000000000001","phone":"13900000000",
					 "name":"刘先生","city":"成都","decorationType":"水电",
					 "address":"成都市高新区天府大道 1 号","area":88.50}
					"""))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.name").value("刘先生"))
			.andExpect(jsonPath("$.data.area").value(88.50));

		verify(ownerProfileService).update(USER_ID, PHONE,
			new OwnerProfileRequest("刘先生", "成都", "水电", "成都市高新区天府大道 1 号",
				new BigDecimal("88.50")));
	}

	@Test
	void invalidAreaReturnsValidationError() throws Exception {
		givenDatabaseUser(UserRole.OWNER);

		mvc.perform(put("/api/v1/owners/me")
				.header("Authorization", bearerToken())
				.contentType(APPLICATION_JSON)
				.content("{\"area\":0.99}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		verify(ownerProfileService, never()).update(any(), any(), any());
	}

	@Test
	void oversizedFieldReturnsValidationError() throws Exception {
		givenDatabaseUser(UserRole.OWNER);

		mvc.perform(put("/api/v1/owners/me")
				.header("Authorization", bearerToken())
				.contentType(APPLICATION_JSON)
				.content("{\"name\":\"" + "人".repeat(81) + "\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		verify(ownerProfileService, never()).update(any(), any(), any());
	}

	private void givenDatabaseUser(UserRole role) {
		User user = mock(User.class);
		when(user.getPhone()).thenReturn(PHONE);
		when(user.getStatus()).thenReturn(UserStatus.ACTIVE);
		when(user.getRoles()).thenReturn(Set.of(role));
		when(users.findById(USER_ID)).thenReturn(Optional.of(user));
	}

	private String bearerToken() {
		String token = tokens.issue(USER_ID, "19999999999", Set.of(UserRole.OWNER)).accessToken();
		return "Bearer " + token;
	}

	private OwnerProfileResponse response() {
		return new OwnerProfileResponse(USER_ID, PHONE, "刘先生", "成都", "水电",
			"成都市高新区天府大道 1 号", new BigDecimal("88.50"), true);
	}
}
