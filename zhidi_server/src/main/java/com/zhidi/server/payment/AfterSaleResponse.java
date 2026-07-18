package com.zhidi.server.payment;

import java.time.Instant;
import java.util.UUID;

public record AfterSaleResponse(
	UUID id,
	UUID bookingId,
	UUID ownerUserId,
	AfterSaleType type,
	String reason,
	String evidence,
	AfterSaleStatus status,
	String resolution,
	Instant createdAt,
	Instant updatedAt
) {

	public static AfterSaleResponse from(AfterSale afterSale) {
		return new AfterSaleResponse(
			afterSale.getId(), afterSale.getBookingId(),
			afterSale.getOwnerUserId(), afterSale.getType(),
			afterSale.getReason(), afterSale.getEvidence(),
			afterSale.getStatus(), afterSale.getResolution(),
			afterSale.getCreatedAt(), afterSale.getUpdatedAt());
	}
}
