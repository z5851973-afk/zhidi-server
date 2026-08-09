package com.zhidi.server.booking;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface BookingRepository extends JpaRepository<Booking, UUID>,
		JpaSpecificationExecutor<Booking> {

	List<Booking> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);

	List<Booking> findByWorkerUserIdOrderByCreatedAtDesc(UUID workerUserId);

	Optional<Booking> findByIdAndWorkerUserId(UUID id, UUID workerUserId);

	Optional<Booking> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select b from Booking b where b.id = :bookingId")
	Optional<Booking> findByIdForUpdate(UUID bookingId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("""
		select b from Booking b
		where b.id = :bookingId and b.serviceRequestId = :requestId
		""")
	Optional<Booking> findCandidateForUpdate(UUID bookingId, UUID requestId);

	List<Booking> findByServiceRequestIdOrderByCreatedAtAsc(UUID serviceRequestId);

	@Query("""
		select b from Booking b
		where b.serviceRequestId in :serviceRequestIds
		order by b.createdAt asc
		""")
	List<Booking> findByServiceRequestIdInOrderByCreatedAtAsc(
		Collection<UUID> serviceRequestIds);

	Optional<Booking> findByServiceRequestIdAndWorkerUserId(
		UUID serviceRequestId, UUID workerUserId);

	@Query("""
		select b from Booking b
		where b.serviceRequestId in :serviceRequestIds
		  and b.workerUserId = :workerUserId
		  and b.status not in :terminalStatuses
		order by b.createdAt desc
		""")
	List<Booking> findActiveByServiceRequestIdsAndWorkerUserId(
		Collection<UUID> serviceRequestIds, UUID workerUserId,
		Collection<BookingStatus> terminalStatuses);

	boolean existsByServiceRequestIdAndWorkerUserId(UUID serviceRequestId, UUID workerUserId);

	long countByWorkerUserIdAndStatus(UUID workerUserId, BookingStatus status);

	@Query("""
		select count(b) from Booking b
		where b.serviceRequestId = :requestId
		  and b.status not in :terminalStatuses
		""")
	long countActiveCandidates(UUID requestId,
		Collection<BookingStatus> terminalStatuses);
}
