package com.zhidi.server.auth;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.slf4j.MDC;
import org.springframework.context.EnvironmentAware;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController implements EnvironmentAware {

	private final AuthService authService;
	private Environment environment;

	public AuthController(AuthService authService) {
		this.authService = authService;
	}

	@Override
	public void setEnvironment(Environment environment) {
		this.environment = environment;
	}

	@PostMapping("/sms-codes")
	public ResponseEntity<ApiResponse<RequestSmsCodeResponse>> issueCode(
			@Valid @RequestBody RequestSmsCodeRequest request,
			HttpServletRequest servletRequest) {
		SmsCodeIssueResult result = authService.issueCode(request.phone(), servletRequest.getRemoteAddr());
		String simulatedCode = environment.acceptsProfiles(Profiles.of("dev"))
			? result.simulatedCode() : null;
		RequestSmsCodeResponse response = new RequestSmsCodeResponse(
			simulatedCode, result.expiresInSeconds(), result.retryAfterSeconds());
		return ResponseEntity.ok(ApiResponse.ok(response, traceId()));
	}

	@PostMapping("/register")
	public ResponseEntity<ApiResponse<RegisterResponse>> register(
			@Valid @RequestBody RegisterRequest request) {
		RegistrationResult result = authService.register(request.phone(), request.code());
		RegisterResponse response = new RegisterResponse(
			result.id(), result.phone(), result.status(), result.roles());
		return ResponseEntity.ok(ApiResponse.ok(response, traceId()));
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
