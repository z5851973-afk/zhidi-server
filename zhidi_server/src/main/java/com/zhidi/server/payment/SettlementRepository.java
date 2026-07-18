package com.zhidi.server.payment;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SettlementRepository extends JpaRepository<Settlement, UUID> {

	Optional<Settlement> findByPaymentOrderId(UUID paymentOrderId);

	List<Settlement> findByWorkerUserIdOrderByCreatedAtDesc(UUID workerUserId);
}
