package com.zhidi.server.booking;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record BookingResponse(
	UUID id,
	UUID serviceRequestId,
	UUID ownerUserId,
	String ownerName,
	String ownerPhone,
	UUID workerUserId,
	String workerName,
	String trade,
	String serviceCity,
	String serviceAddress,
	String remark,
	BigDecimal areaSqm,
	Short bedroomCount,
	Short livingRoomCount,
	Short kitchenCount,
	Short bathroomCount,
	BookingStatus status,
	String cancelledBy,
	String cancelReason,
	Instant cancelledAt,
	boolean arrivalConfirmedByOwner,
	boolean arrivalConfirmedByWorker,
	Instant onSiteAt,
	Instant proposedTime,
	Instant scheduledVisitAt,
	Instant actualOnSiteAt,
	Instant createdAt,
	Instant updatedAt,
	boolean canRemove,
	boolean canReplace
) {
	public BookingResponse(UUID id, UUID serviceRequestId, UUID ownerUserId,
			String ownerName, String ownerPhone, UUID workerUserId,
			String workerName, String trade, String serviceCity,
			String serviceAddress, String remark, BookingStatus status,
			String cancelledBy, String cancelReason, Instant cancelledAt,
			boolean arrivalConfirmedByOwner, boolean arrivalConfirmedByWorker,
			Instant onSiteAt, Instant proposedTime, Instant scheduledVisitAt,
			Instant actualOnSiteAt, Instant createdAt, Instant updatedAt,
			boolean canRemove, boolean canReplace) {
		this(id, serviceRequestId, ownerUserId, ownerName, ownerPhone,
			workerUserId, workerName, trade, serviceCity, serviceAddress, remark,
			null, null, null, null, null, status, cancelledBy, cancelReason,
			cancelledAt, arrivalConfirmedByOwner, arrivalConfirmedByWorker,
			onSiteAt, proposedTime, scheduledVisitAt, actualOnSiteAt, createdAt,
			updatedAt, canRemove, canReplace);
	}
}
