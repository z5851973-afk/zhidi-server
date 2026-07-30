package com.zhidi.server.payment;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "warranty_retentions")
public class WarrantyRetention extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "owner_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID ownerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "payment_order_id", nullable = false, updatable = false,
		unique = true, columnDefinition = "BINARY(16)")
	private UUID paymentOrderId;

	@Column(nullable = false, precision = 12, scale = 2)
	private BigDecimal amount;

	@Column(name = "released_amount", nullable = false, precision = 12, scale = 2)
	private BigDecimal releasedAmount;

	@Column(name = "deducted_amount", nullable = false, precision = 12, scale = 2)
	private BigDecimal deductedAmount;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private WarrantyRetentionStatus status;

	@Column(name = "deduction_reason", length = 300)
	private String deductionReason;

	@Column(name = "released_at")
	private Instant releasedAt;

	protected WarrantyRetention() {
	}

	private WarrantyRetention(UUID workerUserId, UUID ownerUserId,
			UUID bookingId, UUID paymentOrderId, BigDecimal amount) {
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		this.bookingId = Objects.requireNonNull(bookingId);
		this.paymentOrderId = Objects.requireNonNull(paymentOrderId);
		this.amount = normalizeAmount(amount);
		this.releasedAmount = BigDecimal.ZERO.setScale(2);
		this.deductedAmount = BigDecimal.ZERO.setScale(2);
		this.status = WarrantyRetentionStatus.HELD;
	}

	public static WarrantyRetention create(UUID workerUserId, UUID ownerUserId,
			UUID bookingId, UUID paymentOrderId, BigDecimal amount) {
		return new WarrantyRetention(workerUserId, ownerUserId, bookingId,
			paymentOrderId, amount);
	}

	public UUID getWorkerUserId() { return workerUserId; }
	public UUID getOwnerUserId() { return ownerUserId; }
	public UUID getBookingId() { return bookingId; }
	public UUID getPaymentOrderId() { return paymentOrderId; }
	public BigDecimal getAmount() { return amount; }
	public BigDecimal getReleasedAmount() { return releasedAmount; }
	public BigDecimal getDeductedAmount() { return deductedAmount; }
	public WarrantyRetentionStatus getStatus() { return status; }
	public String getDeductionReason() { return deductionReason; }
	public Instant getReleasedAt() { return releasedAt; }

	public BigDecimal remainingAmount() {
		return amount.subtract(releasedAmount).subtract(deductedAmount)
			.max(BigDecimal.ZERO.setScale(2));
	}

	public void deduct(BigDecimal requestedAmount, String reason) {
		if (status != WarrantyRetentionStatus.HELD) {
			throw new IllegalStateException("只有冻结中的质保金才能扣减");
		}
		BigDecimal deduction = normalizeAmount(requestedAmount);
		if (deduction.compareTo(BigDecimal.ZERO) <= 0
				|| deduction.compareTo(remainingAmount()) > 0) {
			throw new IllegalArgumentException("扣减金额必须大于 0 且不能超过剩余质保金");
		}
		if (reason == null || reason.isBlank()) {
			throw new IllegalArgumentException("扣减原因不能为空");
		}
		this.deductedAmount = this.deductedAmount.add(deduction).setScale(2);
		this.deductionReason = reason.trim();
		if (remainingAmount().compareTo(BigDecimal.ZERO) == 0) {
			this.status = WarrantyRetentionStatus.DEDUCTED;
		}
	}

	public void releaseRemaining() {
		if (status != WarrantyRetentionStatus.HELD) {
			throw new IllegalStateException("只有冻结中的质保金才能释放");
		}
		this.releasedAmount = remainingAmount();
		this.status = WarrantyRetentionStatus.RELEASED;
		this.releasedAt = Instant.now();
	}

	private static BigDecimal normalizeAmount(BigDecimal amount) {
		Objects.requireNonNull(amount, "amount");
		return amount.setScale(2, RoundingMode.HALF_UP);
	}
}
