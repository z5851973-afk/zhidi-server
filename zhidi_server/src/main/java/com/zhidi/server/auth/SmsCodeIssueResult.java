package com.zhidi.server.auth;

public record SmsCodeIssueResult(
	String simulatedCode,
	long expiresInSeconds,
	long retryAfterSeconds
) {
}
