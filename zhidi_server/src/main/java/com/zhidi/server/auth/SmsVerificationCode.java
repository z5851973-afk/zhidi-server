package com.zhidi.server.auth;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Objects;

@Entity
@Table(name = "sms_verification_codes")
public class SmsVerificationCode extends BaseEntity {

	@Column(nullable = false, length = 20)
	private String phone;

	@Column(name = "code_hash", nullable = false, length = 64, columnDefinition = "CHAR(64)")
	private String codeHash;

	@Column(name = "request_ip", nullable = false, length = 45)
	private String requestIp;

	@Column(name = "issued_at", nullable = false)
	private Instant issuedAt;

	@Column(name = "expires_at", nullable = false)
	private Instant expiresAt;

	@Column(name = "failed_attempts", nullable = false)
	private int failedAttempts;

	@Column(name = "invalidated_at")
	private Instant invalidatedAt;

	@Column(name = "consumed_at")
	private Instant consumedAt;

	protected SmsVerificationCode() {
	}

	private SmsVerificationCode(String phone, String codeHash, String requestIp,
			Instant issuedAt, Instant expiresAt) {
		this.phone = Objects.requireNonNull(phone);
		this.codeHash = Objects.requireNonNull(codeHash);
		this.requestIp = Objects.requireNonNull(requestIp);
		this.issuedAt = Objects.requireNonNull(issuedAt);
		this.expiresAt = Objects.requireNonNull(expiresAt);
	}

	public static SmsVerificationCode issue(String phone, String codeHash, String requestIp,
			Instant issuedAt, Instant expiresAt) {
		if (!expiresAt.isAfter(issuedAt)) {
			throw new IllegalArgumentException("expiresAt must be after issuedAt");
		}
		return new SmsVerificationCode(phone, codeHash, requestIp, issuedAt, expiresAt);
	}

	public boolean isExpiredAt(Instant now) {
		return !now.isBefore(expiresAt);
	}

	public boolean isActiveAt(Instant now) {
		return consumedAt == null && invalidatedAt == null && !isExpiredAt(now);
	}

	public int recordFailedAttempt(Instant now) {
		failedAttempts++;
		if (failedAttempts >= 5) {
			invalidate(now);
		}
		return failedAttempts;
	}

	public void invalidate(Instant now) {
		if (invalidatedAt == null && consumedAt == null) {
			invalidatedAt = Objects.requireNonNull(now);
		}
	}

	public void consume(Instant now) {
		if (!isActiveAt(now)) {
			throw new IllegalStateException("verification code is not active");
		}
		consumedAt = now;
	}

	public String getPhone() { return phone; }
	public String getCodeHash() { return codeHash; }
	public String getRequestIp() { return requestIp; }
	public Instant getIssuedAt() { return issuedAt; }
	public Instant getExpiresAt() { return expiresAt; }
	public int getFailedAttempts() { return failedAttempts; }
	public Instant getInvalidatedAt() { return invalidatedAt; }
	public Instant getConsumedAt() { return consumedAt; }
}
