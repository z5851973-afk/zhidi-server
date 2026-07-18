package com.zhidi.server.payment;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "settlements")
public class Settlement extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "payment_order_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID paymentOrderId;

	@Column(nullable = false, precision = 12, scale = 2)
	private BigDecimal amount;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private SettlementStatus status;

	@Column(name = "frozen_reason", length = 300)
	private String frozenReason;

	@Column(name = "settled_at")
	private Instant settledAt;

	protected Settlement() {
	}

	private Settlement(UUID workerUserId, UUID bookingId, UUID paymentOrderId,
			BigDecimal amount) {
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.bookingId = Objects.requireNonNull(bookingId);
		this.paymentOrderId = Objects.requireNonNull(paymentOrderId);
		this.amount = Objects.requireNonNull(amount);
		this.status = SettlementStatus.PENDING;
	}

	public static Settlement create(UUID workerUserId, UUID bookingId,
			UUID paymentOrderId, BigDecimal amount) {
		return new Settlement(workerUserId, bookingId, paymentOrderId, amount);
	}

	public UUID getWorkerUserId() { return workerUserId; }
	public UUID getBookingId() { return bookingId; }
	public UUID getPaymentOrderId() { return paymentOrderId; }
	public BigDecimal getAmount() { return amount; }
	public SettlementStatus getStatus() { return status; }
	public String getFrozenReason() { return frozenReason; }
	public Instant getSettledAt() { return settledAt; }

	public void markSettleable() {
		if (this.status != SettlementStatus.PENDING) {
			throw new IllegalStateException("只有 PENDING 状态才能标记为可结算");
		}
		this.status = SettlementStatus.SETTLEABLE;
	}

	public void markSettled() {
		if (this.status != SettlementStatus.SETTLEABLE) {
			throw new IllegalStateException("只有 SETTLEABLE 状态才能标记为已结算");
		}
		this.status = SettlementStatus.SETTLED;
		this.settledAt = Instant.now();
	}

	public void freeze(String reason) {
		this.status = SettlementStatus.FROZEN;
		this.frozenReason = reason;
	}
}
