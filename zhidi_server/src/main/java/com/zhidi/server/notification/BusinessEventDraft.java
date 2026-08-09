package com.zhidi.server.notification;

import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

public record BusinessEventDraft(
		UUID recipientUserId,
		UUID actorUserId,
		BusinessEventType eventType,
		String aggregateType,
		UUID aggregateId,
		UUID bookingId,
		UUID serviceRequestId,
		String idempotencyKey,
		Map<String, Object> payload,
		Instant occurredAt) {

	public BusinessEventDraft {
		Objects.requireNonNull(recipientUserId, "recipientUserId must not be null");
		Objects.requireNonNull(eventType, "eventType must not be null");
		aggregateType = requireText(aggregateType, "aggregateType");
		Objects.requireNonNull(aggregateId, "aggregateId must not be null");
		Objects.requireNonNull(bookingId, "bookingId must not be null");
		Objects.requireNonNull(serviceRequestId,
			"serviceRequestId must not be null");
		idempotencyKey = requireText(idempotencyKey, "idempotencyKey");
		payload = payload == null || payload.isEmpty()
			? Map.of() : Map.copyOf(payload);
		Objects.requireNonNull(occurredAt, "occurredAt must not be null");
	}

	private static String requireText(String value, String field) {
		if (value == null || value.isBlank()) {
			throw new IllegalArgumentException(field + " must not be blank");
		}
		return value.trim();
	}
}
