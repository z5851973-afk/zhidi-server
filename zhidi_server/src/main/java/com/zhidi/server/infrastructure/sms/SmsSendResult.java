package com.zhidi.server.infrastructure.sms;

public record SmsSendResult(
	String code,
	long expiresInSeconds,
	long retryAfterSeconds,
	boolean rateLimited) {

	public static SmsSendResult success(String code, long expiresInSeconds, long retryAfterSeconds) {
		return new SmsSendResult(code, expiresInSeconds, retryAfterSeconds, false);
	}

	public static SmsSendResult rateLimited(long retryAfterSeconds) {
		return new SmsSendResult(null, 0, retryAfterSeconds, true);
	}
}
