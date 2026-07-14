package com.zhidi.server.auth;

import java.security.SecureRandom;
import org.springframework.stereotype.Component;

@Component
public class SecureVerificationCodeGenerator implements VerificationCodeGenerator {

	private final SecureRandom random = new SecureRandom();

	@Override
	public String generate() {
		return "%06d".formatted(random.nextInt(1_000_000));
	}
}
