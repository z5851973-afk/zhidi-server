package com.zhidi.server.payment;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WarrantyRetentionRepository
		extends JpaRepository<WarrantyRetention, UUID> {

	boolean existsByPaymentOrderId(UUID paymentOrderId);

	Optional<WarrantyRetention> findByPaymentOrderId(UUID paymentOrderId);

	List<WarrantyRetention> findByWorkerUserIdOrderByCreatedAtDesc(UUID workerUserId);

	List<WarrantyRetention> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);
}
