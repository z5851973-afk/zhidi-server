package com.zhidi.server.chat;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ChatRoomRepository extends JpaRepository<ChatRoom, UUID> {

	Optional<ChatRoom> findByBookingId(UUID bookingId);

	@Query("""
		select r from ChatRoom r
		where r.ownerUserId = :userId or r.workerUserId = :userId
		order by r.lastMessageAt desc nulls last, r.createdAt desc
		""")
	List<ChatRoom> findByParticipantUserIdOrderByLastMessageAtDesc(UUID userId);
}
