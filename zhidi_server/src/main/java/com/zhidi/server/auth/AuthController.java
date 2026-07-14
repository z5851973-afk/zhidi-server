package com.zhidi.server.auth;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
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
@Tag(name = "认证", description = "业主手机号认证接口")
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
	@Operation(summary = "发送短信验证码", description = "发送登录或注册验证码，并应用手机号和 IP 频率限制")
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
	@Operation(summary = "注册业主", description = "使用短信验证码注册新的业主账户")
	public ResponseEntity<ApiResponse<RegisterResponse>> register(
			@Valid @RequestBody RegisterRequest request) {
		RegistrationResult result = authService.register(request.phone(), request.code());
		RegisterResponse response = new RegisterResponse(
			result.id(), result.phone(), result.status(), result.roles());
		return ResponseEntity.ok(ApiResponse.ok(response, traceId()));
	}

	@PostMapping("/login")
	@Operation(summary = "业主短信验证码登录",
		description = "已有业主直接登录；新手机号自动创建业主账户后登录")
	public ResponseEntity<ApiResponse<LoginResponse>> login(
			@Valid @RequestBody LoginRequest request) {
		LoginResult result = authService.loginOwner(request.phone(), request.code());
		RegistrationResult user = result.user();
		AuthUserResponse authUser = new AuthUserResponse(
			user.id(), user.phone(), user.status(), user.roles());
		LoginResponse response = new LoginResponse(
			result.accessToken(), result.tokenType(), result.expiresInSeconds(), authUser);
		return ResponseEntity.ok(ApiResponse.ok(response, traceId()));
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
