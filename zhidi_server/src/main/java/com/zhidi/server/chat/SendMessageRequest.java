package com.zhidi.server.chat;

import jakarta.validation.constraints.NotBlank;

public record SendMessageRequest(
	@NotBlank String content,
	String type,
	String imageUrl
) {}
