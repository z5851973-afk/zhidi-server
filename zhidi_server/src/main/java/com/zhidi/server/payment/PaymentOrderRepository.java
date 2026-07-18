package com.zhidi.server.payment;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PaymentOrderRepository extends JpaRepository<PaymentOrder, UUID> {

	Optional<PaymentOrder> findByBookingId(UUID bookingId);

	@Query("SELECT p FROM PaymentOrder p WHERE p.ownerUserId = :userId ORDER BY p.createdAt DESC")
	Page<PaymentOrder> findByOwnerUserId(UUID userId, Pageable pageable);

	@Query("SELECT p FROM PaymentOrder p WHERE p.workerUserId = :userId ORDER BY p.createdAt DESC")
	Page<PaymentOrder> findByWorkerUserId(UUID userId, Pageable pageable);

	@Query("SELECT p FROM PaymentOrder p WHERE p.ownerUserId = :userId OR p.workerUserId = :userId ORDER BY p.createdAt DESC")
	Page<PaymentOrder> findByUserId(UUID userId, Pageable pageable);

	List<PaymentOrder> findByBookingIdIn(List<UUID> bookingIds);
}
