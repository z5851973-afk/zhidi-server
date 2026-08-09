package com.zhidi.server.payment;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AfterSaleEventRepository
		extends JpaRepository<AfterSaleEvent, UUID> {

	Optional<AfterSaleEvent> findByAfterSaleIdAndIdempotencyKey(
		UUID afterSaleId, String idempotencyKey);

	List<AfterSaleEvent> findByAfterSaleIdOrderByCreatedAtAscIdAsc(
		UUID afterSaleId);
}
