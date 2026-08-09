package com.zhidi.server.payment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record AfterSaleResponse(
	UUID id,
	UUID bookingId,
	UUID ownerUserId,
	UUID workerUserId,
	AfterSaleType type,
	String reason,
	List<String> evidenceUrls,
	AfterSaleStatus status,
	String resolution,
	UUID warrantyRetentionId,
	BigDecimal warrantyDeductionAmount,
	Instant acceptedAt,
	Instant dueAt,
	Instant resolvedAt,
	Instant closedAt,
	Instant lastActivityAt,
	Instant createdAt,
	Instant updatedAt
) {
	public AfterSaleResponse(UUID id, UUID bookingId, UUID ownerUserId,
			AfterSaleType type, String reason, List<String> evidenceUrls,
			AfterSaleStatus status, String resolution, UUID warrantyRetentionId,
			BigDecimal warrantyDeductionAmount, Instant createdAt,
			Instant updatedAt) {
		this(id, bookingId, ownerUserId, null, type, reason, evidenceUrls, status,
			resolution, warrantyRetentionId, warrantyDeductionAmount, null, null,
			null, null, null, createdAt, updatedAt);
	}

	public static AfterSaleResponse from(AfterSale afterSale) {
		return new AfterSaleResponse(
			afterSale.getId(), afterSale.getBookingId(),
			afterSale.getOwnerUserId(), afterSale.getWorkerUserId(),
			afterSale.getType(), afterSale.getReason(),
			afterSale.getEvidenceUrls(),
			afterSale.getStatus(), afterSale.getResolution(),
			afterSale.getWarrantyRetentionId(),
			afterSale.getWarrantyDeductionAmount(),
			afterSale.getAcceptedAt(), afterSale.getDueAt(),
			afterSale.getResolvedAt(), afterSale.getClosedAt(),
			afterSale.getLastActivityAt(),
			afterSale.getCreatedAt(), afterSale.getUpdatedAt());
	}
}
