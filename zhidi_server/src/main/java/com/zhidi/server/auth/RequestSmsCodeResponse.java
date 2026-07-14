package com.zhidi.server.auth;

import com.fasterxml.jackson.annotation.JsonInclude;

public record RequestSmsCodeResponse(
	@JsonInclude(JsonInclude.Include.NON_NULL)
	String simulatedCode,
	long expiresInSeconds,
	long retryAfterSeconds
) {
}
