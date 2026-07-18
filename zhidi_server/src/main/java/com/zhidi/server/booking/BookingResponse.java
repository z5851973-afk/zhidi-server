package com.zhidi.server.booking;

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
	BookingStatus status,
	String cancelledBy,
	String cancelReason,
	Instant cancelledAt,
	boolean arrivalConfirmedByOwner,
	boolean arrivalConfirmedByWorker,
	Instant onSiteAt,
	Instant proposedTime,
	Instant createdAt,
	Instant updatedAt
) {
}
