package com.zhidi.server.payment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record SettlementResponse(
	UUID id,
	UUID workerUserId,
	UUID bookingId,
	UUID paymentOrderId,
	BigDecimal amount,
	SettlementStatus status,
	String frozenReason,
	Instant settledAt,
	Instant createdAt,
	Instant updatedAt
) {

	public static SettlementResponse from(Settlement settlement) {
		return new SettlementResponse(
			settlement.getId(), settlement.getWorkerUserId(),
			settlement.getBookingId(), settlement.getPaymentOrderId(),
			settlement.getAmount(), settlement.getStatus(),
			settlement.getFrozenReason(), settlement.getSettledAt(),
			settlement.getCreatedAt(), settlement.getUpdatedAt());
	}
}
