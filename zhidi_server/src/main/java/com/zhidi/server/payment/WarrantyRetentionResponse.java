package com.zhidi.server.payment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record WarrantyRetentionResponse(
	UUID id,
	UUID workerUserId,
	UUID ownerUserId,
	UUID bookingId,
	UUID paymentOrderId,
	BigDecimal amount,
	BigDecimal releasedAmount,
	BigDecimal deductedAmount,
	BigDecimal remainingAmount,
	WarrantyRetentionStatus status,
	String deductionReason,
	Instant releasedAt,
	Instant createdAt,
	Instant updatedAt
) {

	public static WarrantyRetentionResponse from(WarrantyRetention retention) {
		return new WarrantyRetentionResponse(
			retention.getId(), retention.getWorkerUserId(),
			retention.getOwnerUserId(), retention.getBookingId(),
			retention.getPaymentOrderId(), retention.getAmount(),
			retention.getReleasedAmount(), retention.getDeductedAmount(),
			retention.remainingAmount(), retention.getStatus(),
			retention.getDeductionReason(), retention.getReleasedAt(),
			retention.getCreatedAt(), retention.getUpdatedAt());
	}
}
