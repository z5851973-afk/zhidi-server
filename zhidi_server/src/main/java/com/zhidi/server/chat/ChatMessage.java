package com.zhidi.server.chat;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "chat_messages")
public class ChatMessage {

	@Id
	@GeneratedValue
	@UuidGenerator
	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(nullable = false, updatable = false, columnDefinition = "BINARY(16)")
	private UUID id;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "room_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID roomId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "sender_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID senderUserId;

	@Enumerated(EnumType.STRING)
	@Column(name = "sender_role", nullable = false, length = 16)
	private SenderRole senderRole;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 16)
	private ChatMessageType type;

	@Column(nullable = false, columnDefinition = "TEXT")
	private String content;

	@Column(name = "image_url", length = 500)
	private String imageUrl;

	@Column(name = "read_at")
	private Instant readAt;

	@Column(name = "created_at", nullable = false, updatable = false)
	private Instant createdAt;

	@Column(nullable = false)
	private long version;

	protected ChatMessage() {
	}

	private ChatMessage(UUID roomId, UUID senderUserId, SenderRole senderRole,
			ChatMessageType type, String content, String imageUrl) {
		this.roomId = Objects.requireNonNull(roomId);
		this.senderUserId = Objects.requireNonNull(senderUserId);
		this.senderRole = Objects.requireNonNull(senderRole);
		this.type = Objects.requireNonNull(type);
		this.content = Objects.requireNonNull(content);
		this.imageUrl = imageUrl;
		this.createdAt = Instant.now();
	}

	public static ChatMessage text(UUID roomId, UUID senderUserId, SenderRole senderRole,
			String content) {
		return new ChatMessage(roomId, senderUserId, senderRole, ChatMessageType.TEXT,
			content, null);
	}

	public static ChatMessage image(UUID roomId, UUID senderUserId, SenderRole senderRole,
			String content, String imageUrl) {
		return new ChatMessage(roomId, senderUserId, senderRole, ChatMessageType.IMAGE,
			content, imageUrl);
	}

	public static ChatMessage system(UUID roomId, String content) {
		return new ChatMessage(roomId, null, SenderRole.SYSTEM, ChatMessageType.SYSTEM,
			content, null);
	}

	public UUID getId() {
		return id;
	}

	public UUID getRoomId() {
		return roomId;
	}

	public UUID getSenderUserId() {
		return senderUserId;
	}

	public SenderRole getSenderRole() {
		return senderRole;
	}

	public ChatMessageType getType() {
		return type;
	}

	public String getContent() {
		return content;
	}

	public String getImageUrl() {
		return imageUrl;
	}

	public Instant getReadAt() {
		return readAt;
	}

	public Instant getCreatedAt() {
		return createdAt;
	}

	public long getVersion() {
		return version;
	}

	public void markRead(Instant at) {
		this.readAt = at;
	}
}
