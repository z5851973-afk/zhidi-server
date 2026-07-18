package com.zhidi.server.infrastructure.sms;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.slf4j.MDC;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/sms")
public class SmsController {

	private final SmsService smsService;

	public SmsController(SmsService smsService) {
		this.smsService = smsService;
	}

	@PostMapping("/send-verify-code")
	public ResponseEntity<ApiResponse<SmsSendResponse>> sendVerifyCode(
			@Valid @RequestBody SmsSendRequest request) {
		SmsSendResult result = smsService.sendVerifyCode(request.phone());
		return ResponseEntity.ok(ApiResponse.ok(
			new SmsSendResponse(result.expiresInSeconds(), result.retryAfterSeconds(),
				result.rateLimited()), traceId()));
	}

	@PostMapping("/verify-code")
	public ResponseEntity<ApiResponse<SmsVerifyResponse>> verifyCode(
			@Valid @RequestBody SmsVerifyRequest request) {
		boolean valid = smsService.verifyCode(request.phone(), request.code());
		return ResponseEntity.ok(ApiResponse.ok(
			new SmsVerifyResponse(valid, valid ? "验证成功" : "验证码错误或已过期"), traceId()));
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}

	public record SmsSendRequest(
		@NotBlank @Pattern(regexp = "\\d{11}") String phone) {}

	public record SmsSendResponse(long expiresInSeconds, long retryAfterSeconds, boolean rateLimited) {}

	public record SmsVerifyRequest(
		@NotBlank @Pattern(regexp = "\\d{11}") String phone,
		@NotBlank String code) {}

	public record SmsVerifyResponse(boolean valid, String message) {}
}
