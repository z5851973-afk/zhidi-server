package com.zhidi.server.chat;

import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, UUID> {

	List<ChatMessage> findByRoomIdOrderByCreatedAtDesc(UUID roomId, Pageable pageable);

	@Query("""
		select count(m) from ChatMessage m
		where m.roomId = :roomId
		  and m.senderUserId <> :userId
		  and m.readAt is null
		""")
	long countUnread(UUID roomId, UUID userId);

	@Modifying
	@Query("""
		update ChatMessage m set m.readAt = CURRENT_TIMESTAMP
		where m.roomId = :roomId
		  and m.senderUserId <> :userId
		  and m.readAt is null
		""")
	int markAllReadInRoom(UUID roomId, UUID userId);
}
