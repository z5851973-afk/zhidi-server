package com.zhidi.server.servicerequest;

import com.zhidi.server.booking.BookingResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record ServiceRequestResponse(
	UUID id,
	UUID ownerUserId,
	String trade,
	String serviceCity,
	String serviceAddress,
	String remark,
	ServiceRequestStatus status,
	List<BookingResponse> candidates,
	Instant createdAt,
	Instant updatedAt
) {
}
