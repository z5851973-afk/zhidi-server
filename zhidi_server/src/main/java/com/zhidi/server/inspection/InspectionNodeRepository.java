package com.zhidi.server.inspection;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface InspectionNodeRepository extends JpaRepository<InspectionNode, UUID> {

	List<InspectionNode> findByBookingIdOrderBySortOrderAsc(UUID bookingId);

	boolean existsByBookingIdAndName(UUID bookingId, String name);

	@Query("select n.bookingId from InspectionNode n where n.id = :id")
	Optional<UUID> findBookingIdById(@Param("id") UUID id);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select n from InspectionNode n where n.id = :id")
	Optional<InspectionNode> findByIdForUpdate(@Param("id") UUID id);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("""
		select n from InspectionNode n
		where n.bookingId = :bookingId
		order by n.sortOrder asc
		""")
	List<InspectionNode> findByBookingIdForUpdate(@Param("bookingId") UUID bookingId);
}
