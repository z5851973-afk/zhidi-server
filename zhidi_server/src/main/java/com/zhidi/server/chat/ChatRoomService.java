package com.zhidi.server.chat;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.common.error.BusinessException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ChatRoomService {

	private final ChatRoomRepository chatRooms;
	private final ChatMessageRepository chatMessages;
	private final BookingRepository bookings;

	public ChatRoomService(ChatRoomRepository chatRooms,
			ChatMessageRepository chatMessages, BookingRepository bookings) {
		this.chatRooms = chatRooms;
		this.chatMessages = chatMessages;
		this.bookings = bookings;
	}

	@Transactional
	public ChatRoom getOrCreateRoom(UUID bookingId, UUID userId) {
		return chatRooms.findByBookingId(bookingId).orElseGet(() -> {
			Booking booking = bookings.findById(bookingId)
				.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
					"BOOKING_NOT_FOUND", "booking not found"));
			if (!booking.getOwnerUserId().equals(userId)
				&& !booking.getWorkerUserId().equals(userId)) {
				throw new BusinessException(HttpStatus.FORBIDDEN,
					"ACCESS_DENIED", "not a participant of this booking");
			}
			ChatRoom room = ChatRoom.create(bookingId,
				booking.getOwnerUserId(), booking.getWorkerUserId());
			return chatRooms.save(room);
		});
	}

	@Transactional
	public ChatRoomResponse getOrCreateRoomResponse(UUID bookingId,
			UUID userId) {
		ChatRoom room = getOrCreateRoom(bookingId, userId);
		return toRoomResponse(room, userId);
	}

	@Transactional(readOnly = true)
	public ChatRoom getRoom(UUID roomId, UUID userId) {
		ChatRoom room = chatRooms.findById(roomId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"ROOM_NOT_FOUND", "chat room not found"));
		if (!room.isParticipant(userId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"ACCESS_DENIED", "not a participant of this chat room");
		}
		return room;
	}

	@Transactional(readOnly = true)
	public List<ChatRoomResponse> listRooms(UUID userId) {
		List<ChatRoom> rooms = chatRooms
			.findByParticipantUserIdOrderByLastMessageAtDesc(userId);
		return rooms.stream()
			.map(room -> toRoomResponse(room, userId))
			.toList();
	}

	@Transactional(readOnly = true)
	public List<ChatMessageResponse> getMessages(UUID roomId, UUID userId,
			int page, int size) {
		ChatRoom room = getRoom(roomId, userId);
		List<ChatMessage> messages = chatMessages
			.findByRoomIdOrderByCreatedAtDesc(roomId,
				PageRequest.of(page, size));
		return messages.stream()
			.map(ChatRoomService::toMessageResponse)
			.toList();
	}

	@Transactional
	public ChatMessageResponse sendMessage(UUID roomId, UUID userId,
			SendMessageRequest request) {
		ChatRoom room = getRoom(roomId, userId);
		SenderRole role = room.senderRoleFor(userId);

		ChatMessageType type = parseType(request.type());
		ChatMessage message = switch (type) {
			case IMAGE -> ChatMessage.image(roomId, userId, role,
				request.content(), request.imageUrl());
			case SYSTEM, TEXT -> ChatMessage.text(roomId, userId, role,
				request.content());
		};

		ChatMessage saved = chatMessages.save(message);
		room.updateLastMessage(request.content(), saved.getCreatedAt());
		chatRooms.save(room);

		return toMessageResponse(saved);
	}

	@Transactional
	public void markAllRead(UUID roomId, UUID userId) {
		getRoom(roomId, userId);
		chatMessages.markAllReadInRoom(roomId, userId);
	}

	private ChatRoomResponse toRoomResponse(ChatRoom room, UUID userId) {
		long unread = chatMessages.countUnread(room.getId(), userId);
		return new ChatRoomResponse(room.getId(), room.getBookingId(),
			room.getOwnerUserId(), room.getWorkerUserId(),
			room.getLastMessageText(), room.getLastMessageAt(),
			unread, room.getCreatedAt());
	}

	static ChatMessageResponse toMessageResponse(ChatMessage message) {
		return new ChatMessageResponse(message.getId(), message.getRoomId(),
			message.getSenderUserId(),
			message.getSenderRole() != null ? message.getSenderRole().name() : "SYSTEM",
			message.getType().name(),
			message.getContent(), message.getImageUrl(),
			message.getReadAt(), message.getCreatedAt());
	}

	private static ChatMessageType parseType(String type) {
		if (type == null || type.isBlank()) return ChatMessageType.TEXT;
		try {
			return ChatMessageType.valueOf(type.toUpperCase());
		} catch (IllegalArgumentException e) {
			return ChatMessageType.TEXT;
		}
	}
}
