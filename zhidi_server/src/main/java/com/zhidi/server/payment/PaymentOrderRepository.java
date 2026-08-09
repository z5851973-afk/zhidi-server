package com.zhidi.server.payment;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PaymentOrderRepository extends JpaRepository<PaymentOrder, UUID> {

	Optional<PaymentOrder> findByBookingId(UUID bookingId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("SELECT p FROM PaymentOrder p WHERE p.id = :id")
	Optional<PaymentOrder> findByIdForUpdate(@Param("id") UUID id);

	@Query("SELECT p FROM PaymentOrder p WHERE p.ownerUserId = :userId ORDER BY p.createdAt DESC")
	Page<PaymentOrder> findByOwnerUserId(UUID userId, Pageable pageable);

	@Query("SELECT p FROM PaymentOrder p WHERE p.workerUserId = :userId ORDER BY p.createdAt DESC")
	Page<PaymentOrder> findByWorkerUserId(UUID userId, Pageable pageable);

	@Query("SELECT p FROM PaymentOrder p WHERE p.ownerUserId = :userId OR p.workerUserId = :userId ORDER BY p.createdAt DESC")
	Page<PaymentOrder> findByUserId(UUID userId, Pageable pageable);

	List<PaymentOrder> findByBookingIdIn(List<UUID> bookingIds);

	@Query("""
		SELECT CASE WHEN COUNT(p) > 0 THEN true ELSE false END
		FROM PaymentOrder p
		WHERE p.id <> :orderId
		  AND (p.constructionPaymentReference = :reference
		       OR p.platformFeeReference = :reference)
		""")
	boolean existsReferenceOnOtherOrder(@Param("reference") String reference,
		@Param("orderId") UUID orderId);

	Page<PaymentOrder> findByPlatformFeeStatus(
		PaymentComponentStatus platformFeeStatus, Pageable pageable);
}
