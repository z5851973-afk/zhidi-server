package com.zhidi.server.auth;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfileService;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
	"spring.autoconfigure.exclude="
		+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
})
@AutoConfigureMockMvc
class AuthControllerTest {

	@Autowired
	MockMvc mvc;

	@MockitoBean
	AuthService authService;

	@MockitoBean
	OwnerProfileService ownerProfileService;

	@MockitoBean
	UserRepository userRepository;

	@Test
	void issuesADevelopmentCodeUsingTheDirectRemoteAddress() throws Exception {
		when(authService.issueCode("13800138000", "192.0.2.10"))
			.thenReturn(new SmsCodeIssueResult("123456", 300, 60));

		mvc.perform(post("/api/v1/auth/sms-codes")
				.with(request -> {
					request.setRemoteAddr("192.0.2.10");
					return request;
				})
				.contentType(APPLICATION_JSON)
				.content("{\"phone\":\"13800138000\"}"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.simulatedCode").value("123456"))
			.andExpect(jsonPath("$.data.expiresInSeconds").value(300));

		verify(authService).issueCode("13800138000", "192.0.2.10");
	}

	@Test
	void registersAnOwner() throws Exception {
		UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000001");
		when(authService.register("13800138000", "123456"))
			.thenReturn(new RegistrationResult(userId, "13800138000",
				UserStatus.ACTIVE, Set.of(UserRole.OWNER)));

		mvc.perform(post("/api/v1/auth/register")
				.contentType(APPLICATION_JSON)
				.content("{\"phone\":\"13800138000\",\"code\":\"123456\"}"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.id").value(userId.toString()))
			.andExpect(jsonPath("$.data.status").value("ACTIVE"))
			.andExpect(jsonPath("$.data.roles[0]").value("OWNER"));
	}

	@Test
	void logsInAnOwnerAndDocumentsTheOperationInChinese() throws Exception {
		UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000002");
		RegistrationResult user = new RegistrationResult(userId, "16600000002",
			UserStatus.ACTIVE, Set.of(UserRole.OWNER));
		when(authService.loginOwner("16600000002", "123456"))
			.thenReturn(new LoginResult("jwt", "Bearer", 2_592_000, user));

		mvc.perform(post("/api/v1/auth/login")
				.contentType(APPLICATION_JSON)
				.content("{\"phone\":\"16600000002\",\"code\":\"123456\"}"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.accessToken").value("jwt"))
			.andExpect(jsonPath("$.data.tokenType").value("Bearer"))
			.andExpect(jsonPath("$.data.expiresInSeconds").value(2_592_000))
			.andExpect(jsonPath("$.data.user.id").value(userId.toString()))
			.andExpect(jsonPath("$.data.user.roles[0]").value("OWNER"));

		mvc.perform(get("/v3/api-docs"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.paths['/api/v1/auth/login'].post.summary")
				.value("业主短信验证码登录"));
	}

	@Test
	void validatesLoginRequestsAndMapsOwnerAccessErrors() throws Exception {
		mvc.perform(post("/api/v1/auth/login")
				.contentType(APPLICATION_JSON)
				.content("{\"phone\":\"16600000002\",\"code\":\"12\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		when(authService.loginOwner("16600000003", "123456"))
			.thenThrow(new BusinessException(HttpStatus.FORBIDDEN,
				"ACCOUNT_DISABLED", "account is disabled"));
		mvc.perform(post("/api/v1/auth/login")
				.contentType(APPLICATION_JSON)
				.content("{\"phone\":\"16600000003\",\"code\":\"123456\"}"))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("ACCOUNT_DISABLED"));

		when(authService.loginOwner("16600000004", "123456"))
			.thenThrow(new BusinessException(HttpStatus.FORBIDDEN,
				"OWNER_ACCESS_DENIED", "owner access is not allowed"));
		mvc.perform(post("/api/v1/auth/login")
				.contentType(APPLICATION_JSON)
				.content("{\"phone\":\"16600000004\",\"code\":\"123456\"}"))
			.andExpect(status().isForbidden())
			.andExpect(jsonPath("$.code").value("OWNER_ACCESS_DENIED"));
	}

	@Test
	void validatesPhoneAndMapsRateLimitErrors() throws Exception {
		mvc.perform(post("/api/v1/auth/sms-codes")
				.contentType(APPLICATION_JSON)
				.content("{\"phone\":\"123\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		when(authService.issueCode("13800138000", "127.0.0.1"))
			.thenThrow(new BusinessException(HttpStatus.TOO_MANY_REQUESTS,
				"SMS_RATE_LIMITED", "too many verification requests"));
		mvc.perform(post("/api/v1/auth/sms-codes")
				.contentType(APPLICATION_JSON)
				.content("{\"phone\":\"13800138000\"}"))
			.andExpect(status().isTooManyRequests())
			.andExpect(jsonPath("$.code").value("SMS_RATE_LIMITED"));
	}

	@Test
	void openApiListsBothAuthOperations() throws Exception {
		mvc.perform(get("/v3/api-docs"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.paths['/api/v1/auth/sms-codes'].post").exists())
			.andExpect(jsonPath("$.paths['/api/v1/auth/register'].post").exists());
	}
}
