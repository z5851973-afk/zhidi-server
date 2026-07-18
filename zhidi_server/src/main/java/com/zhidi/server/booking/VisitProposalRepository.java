package com.zhidi.server.booking;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VisitProposalRepository extends JpaRepository<VisitProposal, UUID> {

	List<VisitProposal> findByBookingIdOrderByCreatedAtDesc(UUID bookingId);

	Optional<VisitProposal> findFirstByBookingIdAndStatusOrderByCreatedAtDesc(
		UUID bookingId, VisitProposalStatus status);
}
