package com.zhidi.server.auth;

public record LoginResult(
	String accessToken,
	String tokenType,
	long expiresInSeconds,
	RegistrationResult user
) {
}
