package com.zhidi.server.quote;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record QuoteResponse(
	UUID id,
	UUID bookingId,
	UUID workerUserId,
	List<QuoteItem> items,
	QuoteStatus status,
	String rejectReason,
	Instant createdAt,
	Instant updatedAt
) {
}
