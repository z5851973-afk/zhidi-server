package com.zhidi.server.workercase;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkerCaseRepository extends JpaRepository<WorkerCase, UUID> {

	List<WorkerCase> findByWorkerUserIdOrderByCreatedAtDesc(UUID workerUserId);

	Optional<WorkerCase> findByIdAndWorkerUserId(UUID id, UUID workerUserId);
}
