package com.zhidi.server.booking;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "visit_proposals")
public class VisitProposal extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@Enumerated(EnumType.STRING)
	@Column(name = "proposed_by", nullable = false, length = 16)
	private VisitProposalActor proposedBy;

	@Column(name = "proposed_time", nullable = false)
	private Instant proposedTime;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private VisitProposalStatus status;

	@Column(name = "reject_reason", length = 300)
	private String rejectReason;

	protected VisitProposal() {
	}

	public VisitProposal(UUID bookingId, VisitProposalActor proposedBy,
			Instant proposedTime) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.proposedBy = Objects.requireNonNull(proposedBy);
		this.proposedTime = Objects.requireNonNull(proposedTime);
		this.status = VisitProposalStatus.PROPOSED;
	}

	public UUID getBookingId() {
		return bookingId;
	}

	public VisitProposalActor getProposedBy() {
		return proposedBy;
	}

	public Instant getProposedTime() {
		return proposedTime;
	}

	public VisitProposalStatus getStatus() {
		return status;
	}

	public String getRejectReason() {
		return rejectReason;
	}

	public void accept() {
		this.status = VisitProposalStatus.ACCEPTED;
	}

	public void reject(String reason) {
		this.status = VisitProposalStatus.REJECTED;
		this.rejectReason = Objects.requireNonNull(reason).trim();
	}
}
