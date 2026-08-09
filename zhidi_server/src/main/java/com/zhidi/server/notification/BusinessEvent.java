package com.zhidi.server.notification;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "business_events")
public class BusinessEvent {

	@Id
	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "event_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID eventId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "recipient_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID recipientUserId;

	@Column(name = "sequence_no", nullable = false, updatable = false)
	private long sequenceNo;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "actor_user_id", updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID actorUserId;

	@Enumerated(EnumType.STRING)
	@Column(name = "event_type", nullable = false, updatable = false, length = 64)
	private BusinessEventType eventType;

	@Column(name = "aggregate_type", nullable = false, updatable = false,
		length = 32)
	private String aggregateType;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "aggregate_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID aggregateId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "service_request_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID serviceRequestId;

	@Column(name = "idempotency_key", nullable = false, updatable = false,
		length = 191)
	private String idempotencyKey;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "JSON", updatable = false)
	private Map<String, Object> payload;

	@Column(name = "occurred_at", nullable = false, updatable = false)
	private Instant occurredAt;

	@Column(name = "read_at")
	private Instant readAt;

	protected BusinessEvent() {
	}

	private BusinessEvent(UUID eventId, long sequenceNo,
			BusinessEventDraft draft) {
		this.eventId = eventId;
		this.recipientUserId = draft.recipientUserId();
		this.sequenceNo = sequenceNo;
		this.actorUserId = draft.actorUserId();
		this.eventType = draft.eventType();
		this.aggregateType = draft.aggregateType();
		this.aggregateId = draft.aggregateId();
		this.bookingId = draft.bookingId();
		this.serviceRequestId = draft.serviceRequestId();
		this.idempotencyKey = draft.idempotencyKey();
		this.payload = draft.payload().isEmpty() ? null : draft.payload();
		this.occurredAt = draft.occurredAt();
	}

	static BusinessEvent create(long sequenceNo, BusinessEventDraft draft) {
		if (sequenceNo < 1) {
			throw new IllegalArgumentException("sequenceNo must be positive");
		}
		return new BusinessEvent(UUID.randomUUID(), sequenceNo, draft);
	}

	public UUID getEventId() { return eventId; }
	public UUID getRecipientUserId() { return recipientUserId; }
	public long getSequenceNo() { return sequenceNo; }
	public UUID getActorUserId() { return actorUserId; }
	public BusinessEventType getEventType() { return eventType; }
	public String getAggregateType() { return aggregateType; }
	public UUID getAggregateId() { return aggregateId; }
	public UUID getBookingId() { return bookingId; }
	public UUID getServiceRequestId() { return serviceRequestId; }
	public String getIdempotencyKey() { return idempotencyKey; }
	public Map<String, Object> getPayload() {
		return payload == null ? Map.of() : Map.copyOf(payload);
	}
	public Instant getOccurredAt() { return occurredAt; }
	public Instant getReadAt() { return readAt; }

	void markRead(Instant firstReadAt) {
		if (readAt == null) {
			readAt = firstReadAt;
		}
	}
}
