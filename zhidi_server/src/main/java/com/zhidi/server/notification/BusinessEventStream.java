package com.zhidi.server.notification;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "business_event_streams")
public class BusinessEventStream {

	@Id
	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "recipient_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID recipientUserId;

	@Column(name = "last_sequence", nullable = false)
	private long lastSequence;

	protected BusinessEventStream() {
	}

	public UUID getRecipientUserId() {
		return recipientUserId;
	}

	public long getLastSequence() {
		return lastSequence;
	}

	long nextSequence() {
		return ++lastSequence;
	}
}
