package com.zhidi.server.payment;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkerWarrantyLedgerEntryRepository
		extends JpaRepository<WorkerWarrantyLedgerEntry, UUID> {
	List<WorkerWarrantyLedgerEntry> findByWorkerUserIdOrderByCreatedAtDesc(
		UUID workerUserId);
	Optional<WorkerWarrantyLedgerEntry> findFirstBySourceTypeAndSourceIdOrderByCreatedAtDesc(
		String sourceType, String sourceId);
	List<WorkerWarrantyLedgerEntry>
		findByWorkerUserIdAndEntryTypeAndSourceTypeOrderByCreatedAtDesc(
			UUID workerUserId, WorkerWarrantyLedgerEntryType entryType,
			String sourceType);
}
