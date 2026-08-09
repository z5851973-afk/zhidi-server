package com.zhidi.server.payment;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AfterSaleRepository extends JpaRepository<AfterSale, UUID> {

	List<AfterSale> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);

	@Query("""
		SELECT a FROM AfterSale a
		WHERE a.ownerUserId = :userId OR a.workerUserId = :userId
		ORDER BY a.createdAt DESC
		""")
	List<AfterSale> findForParticipant(@Param("userId") UUID userId);

	List<AfterSale> findByBookingIdOrderByCreatedAtDesc(UUID bookingId);

	boolean existsByBookingIdAndStatusIn(UUID bookingId,
		Collection<AfterSaleStatus> statuses);

	Page<AfterSale> findByStatus(AfterSaleStatus status, Pageable pageable);
}
