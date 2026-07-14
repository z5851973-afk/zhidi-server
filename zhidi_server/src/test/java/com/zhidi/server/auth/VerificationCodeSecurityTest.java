package com.zhidi.server.auth;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class VerificationCodeSecurityTest {

	@Test
	void generatesSixDigits() {
		VerificationCodeGenerator generator = new SecureVerificationCodeGenerator();
		for (int index = 0; index < 100; index++) {
			assertThat(generator.generate()).matches("\\d{6}");
		}
	}

	@Test
	void hashesWithoutExposingPlaintextAndMatchesCorrectly() {
		VerificationCodeHasher hasher =
			new HmacVerificationCodeHasher("test-secret-at-least-32-characters");

		String digest = hasher.hash("13800138000", "123456");

		assertThat(digest).hasSize(64).doesNotContain("123456");
		assertThat(hasher.matches("13800138000", "123456", digest)).isTrue();
		assertThat(hasher.matches("13800138000", "654321", digest)).isFalse();
	}
}
