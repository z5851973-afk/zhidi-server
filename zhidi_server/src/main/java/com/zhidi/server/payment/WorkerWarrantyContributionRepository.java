package com.zhidi.server.payment;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface WorkerWarrantyContributionRepository
		extends JpaRepository<WorkerWarrantyContribution, UUID> {
	Optional<WorkerWarrantyContribution> findByPaymentOrderId(UUID paymentOrderId);
	Optional<WorkerWarrantyContribution> findByAfterSaleId(UUID afterSaleId);
	List<WorkerWarrantyContribution> findByWorkerUserIdOrderByCreatedAtDesc(
		UUID workerUserId);
	Page<WorkerWarrantyContribution> findByStatus(
		WorkerWarrantyContributionStatus status, Pageable pageable);
	boolean existsByPaymentReferenceAndIdNot(String paymentReference, UUID id);

	@Query("""
		select c from WorkerWarrantyContribution c
		where c.workerUserId = :workerUserId
		  and c.status in (com.zhidi.server.payment.WorkerWarrantyContributionStatus.DUE,
		                   com.zhidi.server.payment.WorkerWarrantyContributionStatus.REPORTED,
		                   com.zhidi.server.payment.WorkerWarrantyContributionStatus.REJECTED)
		order by c.createdAt desc
		""")
	List<WorkerWarrantyContribution> findOutstandingByWorkerUserId(UUID workerUserId);
}
