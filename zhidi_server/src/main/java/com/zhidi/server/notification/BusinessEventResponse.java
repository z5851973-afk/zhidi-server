package com.zhidi.server.notification;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public record BusinessEventResponse(
		UUID eventId,
		long sequenceNo,
		UUID actorUserId,
		BusinessEventType eventType,
		String aggregateType,
		UUID aggregateId,
		UUID bookingId,
		UUID serviceRequestId,
		Map<String, Object> payload,
		Instant occurredAt,
		Instant readAt) {

	static BusinessEventResponse from(BusinessEvent event) {
		return new BusinessEventResponse(
			event.getEventId(),
			event.getSequenceNo(),
			event.getActorUserId(),
			event.getEventType(),
			event.getAggregateType(),
			event.getAggregateId(),
			event.getBookingId(),
			event.getServiceRequestId(),
			event.getPayload(),
			event.getOccurredAt(),
			event.getReadAt());
	}
}
