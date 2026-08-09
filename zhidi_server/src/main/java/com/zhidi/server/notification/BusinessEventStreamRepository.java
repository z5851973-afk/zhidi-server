package com.zhidi.server.notification;

import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface BusinessEventStreamRepository
		extends JpaRepository<BusinessEventStream, UUID> {

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select stream from BusinessEventStream stream "
		+ "where stream.recipientUserId = :recipientUserId")
	Optional<BusinessEventStream> findByIdForUpdate(UUID recipientUserId);
}
