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
@Table(name = "payment_orders")
public class PaymentOrder extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "owner_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID ownerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "quote_id", updatable = false, columnDefinition = "BINARY(16)")
	private UUID quoteId;

	@Column(nullable = false, precision = 12, scale = 2)
	private BigDecimal amount;

	@Column(name = "platform_fee", nullable = false, precision = 12, scale = 2)
	private BigDecimal platformFee;

	@Column(name = "worker_settlement", nullable = false, precision = 12, scale = 2)
	private BigDecimal workerSettlement;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private PaymentOrderStatus status;

	@Column(name = "payment_method", length = 32)
	private String paymentMethod;

	@Column(name = "transaction_id", length = 128)
	private String transactionId;

	@Column(name = "paid_at")
	private Instant paidAt;

	@Column(name = "refunded_at")
	private Instant refundedAt;

	protected PaymentOrder() {
	}

	private PaymentOrder(UUID bookingId, UUID ownerUserId, UUID workerUserId,
			UUID quoteId, BigDecimal amount) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.quoteId = quoteId;
		this.amount = Objects.requireNonNull(amount);
		BigDecimal fee = amount.multiply(new BigDecimal("0.05")).setScale(2,
			java.math.RoundingMode.HALF_UP);
		this.platformFee = fee;
		this.workerSettlement = amount.subtract(fee);
		this.status = PaymentOrderStatus.PENDING;
	}

	public static PaymentOrder create(UUID bookingId, UUID ownerUserId,
			UUID workerUserId, UUID quoteId, BigDecimal amount) {
		return new PaymentOrder(bookingId, ownerUserId, workerUserId, quoteId, amount);
	}

	public UUID getBookingId() { return bookingId; }
	public UUID getOwnerUserId() { return ownerUserId; }
	public UUID getWorkerUserId() { return workerUserId; }
	public UUID getQuoteId() { return quoteId; }
	public BigDecimal getAmount() { return amount; }
	public BigDecimal getPlatformFee() { return platformFee; }
	public BigDecimal getWorkerSettlement() { return workerSettlement; }
	public PaymentOrderStatus getStatus() { return status; }
	public String getPaymentMethod() { return paymentMethod; }
	public String getTransactionId() { return transactionId; }
	public Instant getPaidAt() { return paidAt; }
	public Instant getRefundedAt() { return refundedAt; }

	public void markPaid(String transactionId, String paymentMethod) {
		this.status = PaymentOrderStatus.PAID;
		this.transactionId = transactionId;
		this.paymentMethod = paymentMethod;
		this.paidAt = Instant.now();
	}

	public void markRefunded() {
		this.status = PaymentOrderStatus.REFUNDED;
		this.refundedAt = Instant.now();
	}

	public void cancel() {
		this.status = PaymentOrderStatus.CANCELLED;
	}

	public void markFailed() {
		this.status = PaymentOrderStatus.FAILED;
	}
}
