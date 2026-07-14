package com.zhidi.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.support.MySqlContainerSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class AuthServiceIntegrationTest extends MySqlContainerSupport {

	@Autowired
	AuthService service;

	@Autowired
	SmsVerificationCodeRepository codeRepository;

	@Autowired
	UserRepository userRepository;

	@BeforeEach
	void cleanDatabase() {
		userRepository.deleteAll();
		codeRepository.deleteAll();
	}

	@Test
	void storesOnlyTheHashAndRegistersAnOwner() {
		SmsCodeIssueResult issued = service.issueCode("13800138000", "127.0.0.1");
		SmsVerificationCode stored = codeRepository.findAll().getFirst();

		assertThat(stored.getCodeHash()).doesNotContain(issued.simulatedCode());
		RegistrationResult registered = service.register("13800138000", issued.simulatedCode());

		assertThat(registered.roles()).containsExactly(UserRole.OWNER);
		assertThat(userRepository.findByPhone("13800138000")).isPresent();
		assertThat(codeRepository.findAll().getFirst().getConsumedAt()).isNotNull();
	}

	@Test
	void persistsFailedAttemptsAndInvalidatesOnTheFifthFailure() {
		service.issueCode("13900139000", "127.0.0.2");

		for (int attempt = 1; attempt <= 4; attempt++) {
			assertBusinessCode(() -> service.register("13900139000", "000000"),
				"SMS_CODE_INVALID");
		}
		assertBusinessCode(() -> service.register("13900139000", "000000"),
			"SMS_CODE_ATTEMPTS_EXCEEDED");

		SmsVerificationCode stored = codeRepository.findAll().getFirst();
		assertThat(stored.getFailedAttempts()).isEqualTo(5);
		assertThat(stored.getInvalidatedAt()).isNotNull();
	}

	private void assertBusinessCode(Runnable action, String expectedCode) {
		assertThatThrownBy(action::run)
			.isInstanceOfSatisfying(BusinessException.class,
				error -> assertThat(error.code()).isEqualTo(expectedCode));
	}
}
