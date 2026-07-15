package com.zhidi.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.common.error.BusinessException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class AuthServiceTest {

	private static final Instant NOW = Instant.parse("2026-07-14T01:00:00Z");
	private SmsVerificationCodeRepository codeRepository;
	private UserRepository userRepository;
	private VerificationCodeGenerator generator;
	private VerificationCodeHasher hasher;
	private JwtTokenService jwtTokenService;
	private AuthService service;

	@BeforeEach
	void setUp() {
		codeRepository = mock(SmsVerificationCodeRepository.class);
		userRepository = mock(UserRepository.class);
		generator = mock(VerificationCodeGenerator.class);
		hasher = mock(VerificationCodeHasher.class);
		jwtTokenService = mock(JwtTokenService.class);
		service = new AuthService(codeRepository, userRepository, generator, hasher,
			jwtTokenService, Clock.fixed(NOW, ZoneOffset.UTC));
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
	void registersAnActiveWorkerAndConsumesTheCode() {
		SmsVerificationCode code = SmsVerificationCode.issue(
			"13800138009", "digest", "127.0.0.1", NOW.minusSeconds(10), NOW.plusSeconds(290));
		when(codeRepository
			.findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(
				"13800138009"))
			.thenReturn(Optional.of(code));
		when(hasher.matches("13800138009", "123456", "digest")).thenReturn(true);
		when(userRepository.saveAndFlush(any())).thenAnswer(invocation -> invocation.getArgument(0));

		RegistrationResult result = service.registerWorker("13800138009", "123456");

		assertThat(result.phone()).isEqualTo("13800138009");
		assertThat(result.roles()).containsExactly(UserRole.WORKER);
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

	@Test
	void createsAndLogsInANewOwner() {
		givenValidCode("16600000001", "123456");
		when(userRepository.findByPhone("16600000001")).thenReturn(Optional.empty());
		User persistedOwner = owner("16600000001");
		when(userRepository.saveAndFlush(any(User.class))).thenReturn(persistedOwner);
		when(jwtTokenService.issue(persistedOwner.getId(), persistedOwner.getPhone(),
			persistedOwner.getRoles())).thenReturn(new JwtTokenResult("jwt-new", 2_592_000));

		LoginResult result = service.loginOwner("16600000001", "123456");

		assertThat(result.accessToken()).isEqualTo("jwt-new");
		assertThat(result.tokenType()).isEqualTo("Bearer");
		assertThat(result.user().phone()).isEqualTo("16600000001");
		assertThat(result.user().roles()).containsExactly(UserRole.OWNER);
	}

	@Test
	void createsAndLogsInANewWorker() {
		givenValidCode("16600000009", "123456");
		when(userRepository.findByPhone("16600000009")).thenReturn(Optional.empty());
		User persistedWorker = worker("16600000009");
		when(userRepository.saveAndFlush(any(User.class))).thenReturn(persistedWorker);
		when(jwtTokenService.issue(persistedWorker.getId(), persistedWorker.getPhone(),
			persistedWorker.getRoles())).thenReturn(new JwtTokenResult("jwt-worker-new", 2_592_000));

		LoginResult result = service.loginWorker("16600000009", "123456");

		assertThat(result.accessToken()).isEqualTo("jwt-worker-new");
		assertThat(result.tokenType()).isEqualTo("Bearer");
		assertThat(result.user().phone()).isEqualTo("16600000009");
		assertThat(result.user().roles()).containsExactly(UserRole.WORKER);
	}

	@Test
	void logsInAnExistingActiveOwnerWithoutCreatingAnotherUser() {
		givenValidCode("16600000002", "123456");
		User existingOwner = owner("16600000002");
		when(userRepository.findByPhone("16600000002"))
			.thenReturn(Optional.of(existingOwner));
		when(jwtTokenService.issue(existingOwner.getId(), existingOwner.getPhone(),
			existingOwner.getRoles())).thenReturn(new JwtTokenResult("jwt-existing", 2_592_000));

		LoginResult result = service.loginOwner("16600000002", "123456");

		assertThat(result.user().id()).isEqualTo(existingOwner.getId());
		assertThat(result.accessToken()).isEqualTo("jwt-existing");
		verify(userRepository, org.mockito.Mockito.never()).saveAndFlush(any(User.class));
	}

	@Test
	void logsInAnExistingActiveWorkerWithoutCreatingAnotherUser() {
		givenValidCode("16600000010", "123456");
		User existingWorker = worker("16600000010");
		when(userRepository.findByPhone("16600000010"))
			.thenReturn(Optional.of(existingWorker));
		when(jwtTokenService.issue(existingWorker.getId(), existingWorker.getPhone(),
			existingWorker.getRoles())).thenReturn(new JwtTokenResult("jwt-worker-existing", 2_592_000));

		LoginResult result = service.loginWorker("16600000010", "123456");

		assertThat(result.user().id()).isEqualTo(existingWorker.getId());
		assertThat(result.accessToken()).isEqualTo("jwt-worker-existing");
		verify(userRepository, org.mockito.Mockito.never()).saveAndFlush(any(User.class));
	}

	@Test
	void rejectsDisabledOwners() {
		givenValidCode("16600000003", "123456");
		User disabledOwner = user("16600000003", UserStatus.DISABLED,
			Set.of(UserRole.OWNER));
		when(userRepository.findByPhone("16600000003"))
			.thenReturn(Optional.of(disabledOwner));

		assertBusinessCode(() -> service.loginOwner("16600000003", "123456"),
			"ACCOUNT_DISABLED");
	}

	@Test
	void rejectsUsersWithoutOwnerRole() {
		givenValidCode("16600000004", "123456");
		User worker = user("16600000004", UserStatus.ACTIVE, Set.of(UserRole.WORKER));
		when(userRepository.findByPhone("16600000004")).thenReturn(Optional.of(worker));

		assertBusinessCode(() -> service.loginOwner("16600000004", "123456"),
			"OWNER_ACCESS_DENIED");
	}

	@Test
	void rejectsUsersWithoutWorkerRole() {
		givenValidCode("16600000011", "123456");
		User owner = user("16600000011", UserStatus.ACTIVE, Set.of(UserRole.OWNER));
		when(userRepository.findByPhone("16600000011")).thenReturn(Optional.of(owner));

		assertBusinessCode(() -> service.loginWorker("16600000011", "123456"),
			"WORKER_ACCESS_DENIED");
	}

	@Test
	void cannotReuseAConsumedCodeForLogin() {
		SmsVerificationCode code = validCode("16600000005");
		when(codeRepository
			.findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(
				"16600000005"))
			.thenReturn(Optional.of(code), Optional.empty());
		when(hasher.matches("16600000005", "123456", "digest")).thenReturn(true);
		User owner = owner("16600000005");
		when(userRepository.findByPhone("16600000005")).thenReturn(Optional.of(owner));
		when(jwtTokenService.issue(owner.getId(), owner.getPhone(), owner.getRoles()))
			.thenReturn(new JwtTokenResult("jwt", 2_592_000));

		service.loginOwner("16600000005", "123456");

		assertBusinessCode(() -> service.loginOwner("16600000005", "123456"),
			"SMS_CODE_INVALID");
	}

	private void givenValidCode(String phone, String plaintextCode) {
		SmsVerificationCode code = validCode(phone);
		when(codeRepository
			.findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(phone))
			.thenReturn(Optional.of(code));
		when(hasher.matches(phone, plaintextCode, "digest")).thenReturn(true);
	}

	private SmsVerificationCode validCode(String phone) {
		return SmsVerificationCode.issue(
			phone, "digest", "127.0.0.1", NOW.minusSeconds(10), NOW.plusSeconds(290));
	}

	private User owner(String phone) {
		return user(phone, UserStatus.ACTIVE, Set.of(UserRole.OWNER));
	}

	private User worker(String phone) {
		return user(phone, UserStatus.ACTIVE, Set.of(UserRole.WORKER));
	}

	private User user(String phone, UserStatus status, Set<UserRole> roles) {
		User user = mock(User.class);
		when(user.getId()).thenReturn(UUID.randomUUID());
		when(user.getPhone()).thenReturn(phone);
		when(user.getStatus()).thenReturn(status);
		when(user.getRoles()).thenReturn(roles);
		when(user.hasRole(UserRole.OWNER)).thenReturn(roles.contains(UserRole.OWNER));
		when(user.hasRole(UserRole.WORKER)).thenReturn(roles.contains(UserRole.WORKER));
		return user;
	}

	private void assertBusinessCode(Runnable action, String expectedCode) {
		assertThatThrownBy(action::run)
			.isInstanceOfSatisfying(BusinessException.class,
				error -> assertThat(error.code()).isEqualTo(expectedCode));
	}
}
