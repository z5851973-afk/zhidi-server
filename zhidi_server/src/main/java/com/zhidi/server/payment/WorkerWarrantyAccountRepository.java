package com.zhidi.server.payment;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import jakarta.persistence.LockModeType;

public interface WorkerWarrantyAccountRepository
		extends JpaRepository<WorkerWarrantyAccount, UUID> {
	Optional<WorkerWarrantyAccount> findByWorkerUserId(UUID workerUserId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select a from WorkerWarrantyAccount a where a.workerUserId = :workerUserId")
	Optional<WorkerWarrantyAccount> findByWorkerUserIdForUpdate(UUID workerUserId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select a from WorkerWarrantyAccount a where a.id = :id")
	Optional<WorkerWarrantyAccount> findByIdForUpdate(UUID id);
}
