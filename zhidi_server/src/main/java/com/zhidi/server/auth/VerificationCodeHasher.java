package com.zhidi.server.auth;

public interface VerificationCodeHasher {

	String hash(String phone, String code);

	boolean matches(String phone, String code, String expectedHash);
}
