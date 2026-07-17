package com.zhidi.server.booking;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface BookingRepository extends JpaRepository<Booking, UUID> {

	List<Booking> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);

	List<Booking> findByWorkerUserIdOrderByCreatedAtDesc(UUID workerUserId);

	Optional<Booking> findByIdAndWorkerUserId(UUID id, UUID workerUserId);

	Optional<Booking> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);

	List<Booking> findByServiceRequestIdOrderByCreatedAtAsc(UUID serviceRequestId);

	boolean existsByServiceRequestIdAndWorkerUserId(UUID serviceRequestId, UUID workerUserId);

	@Query("""
		select count(b) from Booking b
		where b.serviceRequestId = :requestId
		  and b.status not in :terminalStatuses
		""")
	long countActiveCandidates(UUID requestId,
		Collection<BookingStatus> terminalStatuses);
}
