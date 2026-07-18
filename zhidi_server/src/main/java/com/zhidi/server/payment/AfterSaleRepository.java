package com.zhidi.server.payment;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AfterSaleRepository extends JpaRepository<AfterSale, UUID> {

	List<AfterSale> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);

	List<AfterSale> findByBookingIdOrderByCreatedAtDesc(UUID bookingId);
}
