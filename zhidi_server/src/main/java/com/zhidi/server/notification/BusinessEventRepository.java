package com.zhidi.server.notification;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusinessEventRepository extends JpaRepository<BusinessEvent, UUID> {

	Optional<BusinessEvent> findByRecipientUserIdAndIdempotencyKey(
		UUID recipientUserId, String idempotencyKey);

	Optional<BusinessEvent> findByEventIdAndRecipientUserId(
		UUID eventId, UUID recipientUserId);

	List<BusinessEvent> findByRecipientUserIdAndSequenceNoGreaterThanOrderBySequenceNoAsc(
		UUID recipientUserId, long sequenceNo, Pageable pageable);

	List<BusinessEvent> findByRecipientUserIdOrderBySequenceNoAsc(
		UUID recipientUserId);
}
