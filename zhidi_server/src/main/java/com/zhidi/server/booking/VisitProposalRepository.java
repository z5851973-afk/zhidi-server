package com.zhidi.server.booking;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface VisitProposalRepository extends JpaRepository<VisitProposal, UUID> {

	List<VisitProposal> findByBookingIdOrderByCreatedAtDesc(UUID bookingId);

	Optional<VisitProposal> findFirstByBookingIdAndStatusOrderByCreatedAtDesc(
		UUID bookingId, VisitProposalStatus status);

	@Query("""
		select p from VisitProposal p
		where p.bookingId in :bookingIds and p.status in :statuses
		order by p.createdAt desc
		""")
	List<VisitProposal> findVisibleByBookingIds(
		Collection<UUID> bookingIds, Collection<VisitProposalStatus> statuses);
}
