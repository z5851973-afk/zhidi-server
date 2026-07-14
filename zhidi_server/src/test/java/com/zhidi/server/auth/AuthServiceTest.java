package com.zhidi.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.error.BusinessException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class AuthServiceTest {

	private static final Instant NOW = Instant.parse("2026-07-14T01:00:00Z");
	private SmsVerificationCodeRepository codeRepository;
	private UserRepository userRepository;
	private VerificationCodeGenerator generator;
	private VerificationCodeHasher hasher;
	private AuthService service;

	@BeforeEach
	void setUp() {
		codeRepository = mock(SmsVerificationCodeRepository.class);
		userRepository = mock(UserRepository.class);
		generator = mock(VerificationCodeGenerator.class);
		hasher = mock(VerificationCodeHasher.class);
		service = new AuthService(codeRepository, userRepository, generator, hasher,
			Clock.fixed(NOW, ZoneOffset.UTC));
	}

	@Test
	void issuesAHashedCodeForFiveMinutes() {
		when(generator.generate()).thenReturn("123456");
		when(hasher.hash("13800138000", "123456")).thenReturn("digest");

		SmsCodeIssueResult result = service.issueCode("138 0013 8000", "127.0.0.1");

		assertThat(result.simulatedCode()).isEqualTo("123456");
		assertThat(result.expiresInSeconds()).isEqualTo(300);
		verify(codeRepository).invalidateActiveForPhone("13800138000", NOW);
		verify(codeRepository).save(any(SmsVerificationCode.class));
	}

	@Test
	void rejectsRequestsDuringTheSixtySecondCooldown() {
		SmsVerificationCode recent = SmsVerificationCode.issue(
			"13800138000", "digest", "127.0.0.1", NOW.minusSeconds(59), NOW.plusSeconds(241));
		when(codeRepository.findTopByPhoneOrderByIssuedAtDesc("13800138000"))
			.thenReturn(Optional.of(recent));

		assertBusinessCode(() -> service.issueCode("13800138000", "127.0.0.1"),
			"SMS_RATE_LIMITED");
	}

	@Test
	void rejectsTheSixthPhoneRequestWithinAnHour() {
		when(codeRepository.countByPhoneAndIssuedAtGreaterThanEqual(
			"13800138000", NOW.minusSeconds(3600))).thenReturn(5L);

		assertBusinessCode(() -> service.issueCode("13800138000", "127.0.0.1"),
			"SMS_RATE_LIMITED");
	}

	@Test
	void rejectsTheEleventhPhoneRequestWithinADay() {
		when(codeRepository.countByPhoneAndIssuedAtGreaterThanEqual(
			"13800138000", NOW.minusSeconds(3600))).thenReturn(4L);
		when(codeRepository.countByPhoneAndIssuedAtGreaterThanEqual(
			"13800138000", NOW.minusSeconds(86400))).thenReturn(10L);

		assertBusinessCode(() -> service.issueCode("13800138000", "127.0.0.1"),
			"SMS_RATE_LIMITED");
	}

	@Test
	void rejectsTheTwentyFirstIpRequestWithinAnHour() {
		when(codeRepository.countByRequestIpAndIssuedAtGreaterThanEqual(
			"127.0.0.1", NOW.minusSeconds(3600))).thenReturn(20L);

		assertBusinessCode(() -> service.issueCode("13800138000", "127.0.0.1"),
			"SMS_RATE_LIMITED");
	}

	@Test
	void rejectsTheFiftyFirstIpRequestWithinADay() {
		when(codeRepository.countByRequestIpAndIssuedAtGreaterThanEqual(
			"127.0.0.1", NOW.minusSeconds(3600))).thenReturn(19L);
		when(codeRepository.countByRequestIpAndIssuedAtGreaterThanEqual(
			"127.0.0.1", NOW.minusSeconds(86400))).thenReturn(50L);

		assertBusinessCode(() -> service.issueCode("13800138000", "127.0.0.1"),
			"SMS_RATE_LIMITED");
	}

	@Test
	void registersAnActiveOwnerAndConsumesTheCode() {
		SmsVerificationCode code = SmsVerificationCode.issue(
			"13800138000", "digest", "127.0.0.1", NOW.minusSeconds(10), NOW.plusSeconds(290));
		when(codeRepository
			.findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(
				"13800138000"))
			.thenReturn(Optional.of(code));
		when(hasher.matches("13800138000", "123456", "digest")).thenReturn(true);
		when(userRepository.saveAndFlush(any())).thenAnswer(invocation -> invocation.getArgument(0));

		RegistrationResult result = service.register("13800138000", "123456");

		assertThat(result.phone()).isEqualTo("13800138000");
		assertThat(result.roles()).containsExactly(UserRole.OWNER);
		assertThat(code.getConsumedAt()).isEqualTo(NOW);
	}

	@Test
	void invalidatesAfterFiveWrongAttempts() {
		SmsVerificationCode code = SmsVerificationCode.issue(
			"13800138000", "digest", "127.0.0.1", NOW.minusSeconds(10), NOW.plusSeconds(290));
		when(codeRepository
			.findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(
				"13800138000"))
			.thenReturn(Optional.of(code));

		for (int attempt = 1; attempt < 5; attempt++) {
			assertBusinessCode(() -> service.register("13800138000", "000000"),
				"SMS_CODE_INVALID");
		}
		assertBusinessCode(() -> service.register("13800138000", "000000"),
			"SMS_CODE_ATTEMPTS_EXCEEDED");
		assertThat(code.getInvalidatedAt()).isEqualTo(NOW);
	}

	@Test
	void rejectsAnAlreadyRegisteredPhone() {
		when(userRepository.findByPhone("13800138000")).thenReturn(Optional.of(mock()));
		assertBusinessCode(() -> service.register("13800138000", "123456"),
			"PHONE_ALREADY_REGISTERED");
	}

	private void assertBusinessCode(Runnable action, String expectedCode) {
		assertThatThrownBy(action::run)
			.isInstanceOfSatisfying(BusinessException.class,
				error -> assertThat(error.code()).isEqualTo(expectedCode));
	}
}
