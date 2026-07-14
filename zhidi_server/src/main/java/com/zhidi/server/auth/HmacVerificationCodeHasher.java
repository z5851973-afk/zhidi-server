package com.zhidi.server.auth;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class HmacVerificationCodeHasher implements VerificationCodeHasher {

	private static final String ALGORITHM = "HmacSHA256";
	private final byte[] secret;

	public HmacVerificationCodeHasher(@Value("${auth.sms.hmac-secret}") String secret) {
		if (secret == null || secret.length() < 32) {
			throw new IllegalArgumentException("auth.sms.hmac-secret must contain at least 32 characters");
		}
		this.secret = secret.getBytes(StandardCharsets.UTF_8);
	}

	@Override
	public String hash(String phone, String code) {
		try {
			Mac mac = Mac.getInstance(ALGORITHM);
			mac.init(new SecretKeySpec(secret, ALGORITHM));
			return HexFormat.of().formatHex(
				mac.doFinal((phone + ":" + code).getBytes(StandardCharsets.UTF_8)));
		}
		catch (GeneralSecurityException exception) {
			throw new IllegalStateException("HMAC-SHA256 is unavailable", exception);
		}
	}

	@Override
	public boolean matches(String phone, String code, String expectedHash) {
		return MessageDigest.isEqual(
			hash(phone, code).getBytes(StandardCharsets.US_ASCII),
			expectedHash.getBytes(StandardCharsets.US_ASCII));
	}
}
