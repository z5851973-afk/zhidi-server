package com.zhidi.server.chat;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "chat_rooms")
public class ChatRoom extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, unique = true, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "owner_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID ownerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@Column(name = "last_message_text", length = 500)
	private String lastMessageText;

	@Column(name = "last_message_at")
	private Instant lastMessageAt;

	protected ChatRoom() {
	}

	private ChatRoom(UUID bookingId, UUID ownerUserId, UUID workerUserId) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		this.workerUserId = Objects.requireNonNull(workerUserId);
	}

	public static ChatRoom create(UUID bookingId, UUID ownerUserId, UUID workerUserId) {
		return new ChatRoom(bookingId, ownerUserId, workerUserId);
	}

	public UUID getBookingId() {
		return bookingId;
	}

	public UUID getOwnerUserId() {
		return ownerUserId;
	}

	public UUID getWorkerUserId() {
		return workerUserId;
	}

	public String getLastMessageText() {
		return lastMessageText;
	}

	public Instant getLastMessageAt() {
		return lastMessageAt;
	}

	public void updateLastMessage(String text, Instant at) {
		this.lastMessageText = text != null && text.length() > 500
			? text.substring(0, 500) : text;
		this.lastMessageAt = at;
	}

	public boolean isParticipant(UUID userId) {
		return ownerUserId.equals(userId) || workerUserId.equals(userId);
	}

	public SenderRole senderRoleFor(UUID userId) {
		if (ownerUserId.equals(userId)) return SenderRole.OWNER;
		if (workerUserId.equals(userId)) return SenderRole.WORKER;
		throw new IllegalArgumentException("user is not a participant of this room");
	}
}
