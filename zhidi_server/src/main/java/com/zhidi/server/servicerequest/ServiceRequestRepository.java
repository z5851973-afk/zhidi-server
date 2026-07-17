package com.zhidi.server.servicerequest;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface ServiceRequestRepository extends JpaRepository<ServiceRequest, UUID> {

	List<ServiceRequest> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);

	List<ServiceRequest> findByOwnerUserIdAndTradeAndServiceCityAndStatusOrderByCreatedAtDesc(
			UUID ownerUserId, String trade, String serviceCity, ServiceRequestStatus status);

	@Query("""
		select r from ServiceRequest r
		where r.id = :id and r.ownerUserId = :ownerId
		""")
	Optional<ServiceRequest> findByIdAndOwnerUserId(UUID id, UUID ownerId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("""
		select r from ServiceRequest r
		where r.id = :id and r.ownerUserId = :ownerId
		""")
	Optional<ServiceRequest> findOwnedForUpdate(UUID id, UUID ownerId);
}
