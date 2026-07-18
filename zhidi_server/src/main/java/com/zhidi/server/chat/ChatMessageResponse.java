package com.zhidi.server.chat;

import java.time.Instant;
import java.util.UUID;

public record ChatMessageResponse(
	UUID id,
	UUID roomId,
	UUID senderUserId,
	String senderRole,
	String type,
	String content,
	String imageUrl,
	Instant readAt,
	Instant createdAt
) {}
