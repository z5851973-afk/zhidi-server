package com.zhidi.server.chat;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/chat")
public class ChatController {

	private final ChatRoomService chatRoomService;

	public ChatController(ChatRoomService chatRoomService) {
		this.chatRoomService = chatRoomService;
	}

	@GetMapping("/rooms")
	ResponseEntity<ApiResponse<List<ChatRoomResponse>>> listRooms(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		List<ChatRoomResponse> rooms = chatRoomService.listRooms(principal.userId());
		return ResponseEntity.ok(ApiResponse.ok(rooms, traceId()));
	}

	@PostMapping("/rooms/by-booking/{bookingId}")
	ResponseEntity<ApiResponse<ChatRoomResponse>> getOrCreateRoom(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID bookingId) {
		ChatRoomResponse room = chatRoomService
			.getOrCreateRoomResponse(bookingId, principal.userId());
		return ResponseEntity.ok(ApiResponse.ok(room, traceId()));
	}

	@GetMapping("/rooms/{roomId}/messages")
	ResponseEntity<ApiResponse<List<ChatMessageResponse>>> getMessages(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID roomId,
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size) {
		List<ChatMessageResponse> messages = chatRoomService
			.getMessages(roomId, principal.userId(), page, size);
		return ResponseEntity.ok(ApiResponse.ok(messages, traceId()));
	}

	@PostMapping("/rooms/{roomId}/messages")
	ResponseEntity<ApiResponse<ChatMessageResponse>> sendMessage(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID roomId,
			@Valid @RequestBody SendMessageRequest request) {
		ChatMessageResponse message = chatRoomService
			.sendMessage(roomId, principal.userId(), request);
		return ResponseEntity.ok(ApiResponse.ok(message, traceId()));
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
