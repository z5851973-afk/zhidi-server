package com.zhidi.server.payment;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "payment_reference_claims")
public class PaymentReferenceClaim {

	@Id
	@Column(name = "payment_reference", nullable = false, updatable = false,
		length = 128)
	private String paymentReference;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "payment_order_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID paymentOrderId;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, updatable = false, length = 32)
	private PaymentReferenceComponent component;

	@Column(name = "created_at", nullable = false, updatable = false)
	private Instant createdAt;

	protected PaymentReferenceClaim() {}

	private PaymentReferenceClaim(String paymentReference, UUID paymentOrderId,
			PaymentReferenceComponent component) {
		String normalized = Objects.requireNonNull(paymentReference).trim();
		if (normalized.isEmpty() || normalized.length() > 128) {
			throw new IllegalArgumentException("交易参考号格式无效");
		}
		this.paymentReference = normalized;
		this.paymentOrderId = Objects.requireNonNull(paymentOrderId);
		this.component = Objects.requireNonNull(component);
		this.createdAt = Instant.now();
	}

	public static PaymentReferenceClaim create(String paymentReference,
			UUID paymentOrderId, PaymentReferenceComponent component) {
		return new PaymentReferenceClaim(paymentReference, paymentOrderId, component);
	}

	public String getPaymentReference() {
		return paymentReference;
	}

	public UUID getPaymentOrderId() {
		return paymentOrderId;
	}

	public PaymentReferenceComponent getComponent() {
		return component;
	}

	public Instant getCreatedAt() {
		return createdAt;
	}

	public boolean belongsTo(UUID orderId, PaymentReferenceComponent component) {
		return paymentOrderId.equals(orderId) && this.component == component;
	}
}
