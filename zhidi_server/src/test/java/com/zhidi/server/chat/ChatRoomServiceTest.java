package com.zhidi.server.chat;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class ChatRoomServiceTest {

	@Test
	void imageMessageUsesContentUrlWhenLegacyClientOmitsImageUrlField() {
		ChatRoomRepository rooms = mock(ChatRoomRepository.class);
		ChatMessageRepository messages = mock(ChatMessageRepository.class);
		ChatRoom room = mock(ChatRoom.class);
		UUID roomId = UUID.randomUUID();
		UUID userId = UUID.randomUUID();
		when(rooms.findById(roomId)).thenReturn(Optional.of(room));
		when(room.isParticipant(userId)).thenReturn(true);
		when(room.senderRoleFor(userId)).thenReturn(SenderRole.WORKER);
		when(messages.save(any(ChatMessage.class)))
			.thenAnswer(invocation -> invocation.getArgument(0));
		ChatRoomService service = new ChatRoomService(
			rooms, messages, mock(com.zhidi.server.booking.BookingRepository.class));

		service.sendMessage(roomId, userId,
			new SendMessageRequest("/uploads/chat/site.jpg", "IMAGE", null));

		ArgumentCaptor<ChatMessage> captor = ArgumentCaptor.forClass(ChatMessage.class);
		org.mockito.Mockito.verify(messages).save(captor.capture());
		assertThat(captor.getValue().getImageUrl()).isEqualTo("/uploads/chat/site.jpg");
	}
}
