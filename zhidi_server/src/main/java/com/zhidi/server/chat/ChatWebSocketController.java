package com.zhidi.server.chat;

import java.security.Principal;
import java.util.UUID;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

@Controller
public class ChatWebSocketController {

	private final ChatRoomService chatRoomService;
	private final SimpMessagingTemplate messagingTemplate;

	public ChatWebSocketController(ChatRoomService chatRoomService,
			SimpMessagingTemplate messagingTemplate) {
		this.chatRoomService = chatRoomService;
		this.messagingTemplate = messagingTemplate;
	}

	@MessageMapping("/chat/{roomId}")
	public void handleMessage(@DestinationVariable UUID roomId,
			@Payload SendMessageRequest request, Principal principal) {
		UUID userId = UUID.fromString(principal.getName());
		ChatMessageResponse message = chatRoomService
			.sendMessage(roomId, userId, request);

		ChatRoom room = chatRoomService.getRoom(roomId, userId);
		UUID recipientId = room.getOwnerUserId().equals(userId)
			? room.getWorkerUserId() : room.getOwnerUserId();

		messagingTemplate.convertAndSendToUser(
			recipientId.toString(), "/queue/chat", message);
	}
}
