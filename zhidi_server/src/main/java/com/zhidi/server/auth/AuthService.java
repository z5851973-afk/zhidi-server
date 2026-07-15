package com.zhidi.server.auth;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.common.error.BusinessException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

	private static final Duration CODE_TTL = Duration.ofMinutes(5);
	private static final Duration COOLDOWN = Duration.ofSeconds(60);
	private final SmsVerificationCodeRepository codeRepository;
	private final UserRepository userRepository;
	private final VerificationCodeGenerator generator;
	private final VerificationCodeHasher hasher;
	private final JwtTokenService jwtTokenService;
	private final Clock clock;

	public AuthService(SmsVerificationCodeRepository codeRepository, UserRepository userRepository,
			VerificationCodeGenerator generator, VerificationCodeHasher hasher,
			JwtTokenService jwtTokenService, Clock clock) {
		this.codeRepository = codeRepository;
		this.userRepository = userRepository;
		this.generator = generator;
		this.hasher = hasher;
		this.jwtTokenService = jwtTokenService;
		this.clock = clock;
	}

	@Transactional(isolation = Isolation.SERIALIZABLE)
	public SmsCodeIssueResult issueCode(String rawPhone, String requestIp) {
		String phone = User.normalizePhone(rawPhone);
		Instant now = clock.instant();
		codeRepository.findTopByPhoneOrderByIssuedAtDesc(phone).ifPresent(latest -> {
			Instant retryAt = latest.getIssuedAt().plus(COOLDOWN);
			if (retryAt.isAfter(now)) {
				throw rateLimited(Duration.between(now, retryAt).toSeconds());
			}
		});

		requireBelow(codeRepository.countByPhoneAndIssuedAtGreaterThanEqual(
			phone, now.minus(Duration.ofHours(1))), 5);
		requireBelow(codeRepository.countByPhoneAndIssuedAtGreaterThanEqual(
			phone, now.minus(Duration.ofHours(24))), 10);
		requireBelow(codeRepository.countByRequestIpAndIssuedAtGreaterThanEqual(
			requestIp, now.minus(Duration.ofHours(1))), 20);
		requireBelow(codeRepository.countByRequestIpAndIssuedAtGreaterThanEqual(
			requestIp, now.minus(Duration.ofHours(24))), 50);

		codeRepository.invalidateActiveForPhone(phone, now);
		String plaintextCode = generator.generate();
		codeRepository.save(SmsVerificationCode.issue(
			phone, hasher.hash(phone, plaintextCode), requestIp, now, now.plus(CODE_TTL)));
		return new SmsCodeIssueResult(plaintextCode, CODE_TTL.toSeconds(), COOLDOWN.toSeconds());
	}

	@Transactional(noRollbackFor = BusinessException.class)
	public RegistrationResult register(String rawPhone, String code) {
		return register(rawPhone, code, UserRole.OWNER);
	}

	@Transactional(noRollbackFor = BusinessException.class)
	public RegistrationResult registerWorker(String rawPhone, String code) {
		return register(rawPhone, code, UserRole.WORKER);
	}

	@Transactional(noRollbackFor = BusinessException.class)
	public LoginResult loginOwner(String rawPhone, String code) {
		return login(rawPhone, code, UserRole.OWNER);
	}

	@Transactional(noRollbackFor = BusinessException.class)
	public LoginResult loginWorker(String rawPhone, String code) {
		return login(rawPhone, code, UserRole.WORKER);
	}

	private RegistrationResult register(String rawPhone, String code, UserRole role) {
		String phone = User.normalizePhone(rawPhone);
		if (userRepository.findByPhone(phone).isPresent()) {
			throw business(HttpStatus.CONFLICT, "PHONE_ALREADY_REGISTERED", "phone is already registered");
		}

		verifyAndConsume(phone, code, clock.instant());
		User user = create(phone, role);
		return registrationResult(user);
	}

	private LoginResult login(String rawPhone, String code, UserRole role) {
		String phone = User.normalizePhone(rawPhone);
		verifyAndConsume(phone, code, clock.instant());

		User user = userRepository.findByPhone(phone).orElseGet(() -> create(phone, role));
		requireRoleAccess(user, role);
		JwtTokenResult token = jwtTokenService.issue(
			user.getId(), user.getPhone(), user.getRoles());
		return new LoginResult(token.accessToken(), "Bearer", token.expiresInSeconds(),
			registrationResult(user));
	}

	private User create(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		try {
			return userRepository.saveAndFlush(user);
		}
		catch (DataIntegrityViolationException exception) {
			return userRepository.findByPhone(phone).orElseThrow(() -> exception);
		}
	}

	private void requireRoleAccess(User user, UserRole role) {
		if (user.getStatus() == UserStatus.DISABLED) {
			throw business(HttpStatus.FORBIDDEN, "ACCOUNT_DISABLED", "account is disabled");
		}
		if (role == UserRole.OWNER && !user.hasRole(UserRole.OWNER)) {
			throw business(HttpStatus.FORBIDDEN, "OWNER_ACCESS_DENIED", "owner access is not allowed");
		}
		if (role == UserRole.WORKER && !user.hasRole(UserRole.WORKER)) {
			throw business(HttpStatus.FORBIDDEN, "WORKER_ACCESS_DENIED", "worker access is not allowed");
		}
	}

	private void verifyAndConsume(String phone, String code, Instant now) {
		if (code == null || !code.matches("\\d{6}")) {
			throw business(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "verification code must contain six digits");
		}
		SmsVerificationCode verification = codeRepository
			.findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(phone)
			.orElseThrow(() -> business(HttpStatus.BAD_REQUEST,
				"SMS_CODE_INVALID", "verification code is invalid"));
		if (verification.isExpiredAt(now)) {
			verification.invalidate(now);
			throw business(HttpStatus.BAD_REQUEST, "SMS_CODE_EXPIRED", "verification code has expired");
		}
		if (!hasher.matches(phone, code, verification.getCodeHash())) {
			int attempts = verification.recordFailedAttempt(now);
			if (attempts >= 5) {
				throw business(HttpStatus.TOO_MANY_REQUESTS,
					"SMS_CODE_ATTEMPTS_EXCEEDED", "too many incorrect verification attempts");
			}
			throw business(HttpStatus.BAD_REQUEST, "SMS_CODE_INVALID", "verification code is invalid");
		}

		verification.consume(now);
	}

	private RegistrationResult registrationResult(User user) {
		return new RegistrationResult(
			user.getId(), user.getPhone(), user.getStatus(), user.getRoles());
	}

	private void requireBelow(long currentCount, long limit) {
		if (currentCount >= limit) {
			throw rateLimited(60);
		}
	}

	private BusinessException rateLimited(long retryAfterSeconds) {
		return business(HttpStatus.TOO_MANY_REQUESTS, "SMS_RATE_LIMITED",
			"too many verification requests; retry after " + Math.max(1, retryAfterSeconds) + " seconds");
	}

	private BusinessException business(HttpStatus status, String code, String message) {
		return new BusinessException(status, code, message);
	}
}
