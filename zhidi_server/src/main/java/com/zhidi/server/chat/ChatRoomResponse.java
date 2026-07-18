package com.zhidi.server.chat;

import java.time.Instant;
import java.util.UUID;

public record ChatRoomResponse(
	UUID id,
	UUID bookingId,
	UUID ownerUserId,
	UUID workerUserId,
	String lastMessageText,
	Instant lastMessageAt,
	long unreadCount,
	Instant createdAt
) {}
