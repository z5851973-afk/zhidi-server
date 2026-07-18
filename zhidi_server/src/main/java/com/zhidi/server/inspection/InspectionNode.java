package com.zhidi.server.inspection;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "inspection_nodes")
public class InspectionNode extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@Column(nullable = false, length = 100)
	private String name;

	@Column(columnDefinition = "TEXT")
	private String description;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private InspectionNodeStatus status;

	@Column(name = "sort_order", nullable = false)
	private int sortOrder;

	protected InspectionNode() {
	}

	private InspectionNode(UUID bookingId, String name, String description,
			int sortOrder) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.name = Objects.requireNonNull(name);
		this.description = description;
		this.sortOrder = sortOrder;
		this.status = InspectionNodeStatus.PENDING;
	}

	public static InspectionNode create(UUID bookingId, String name,
			String description, int sortOrder) {
		return new InspectionNode(bookingId, name, description, sortOrder);
	}

	public UUID getBookingId() { return bookingId; }
	public String getName() { return name; }
	public String getDescription() { return description; }
	public InspectionNodeStatus getStatus() { return status; }
	public int getSortOrder() { return sortOrder; }

	public void requestInspection() {
		if (this.status != InspectionNodeStatus.PENDING
				&& this.status != InspectionNodeStatus.FAILED) {
			throw new IllegalStateException(
				"只有待验收或未通过的节点才能申请验收，当前状态: " + this.status);
		}
		this.status = InspectionNodeStatus.INSPECTING;
	}

	public void markPassed() {
		if (this.status != InspectionNodeStatus.INSPECTING) {
			throw new IllegalStateException(
				"只有验收中的节点才能标记通过，当前状态: " + this.status);
		}
		this.status = InspectionNodeStatus.PASSED;
	}

	public void markFailed() {
		if (this.status != InspectionNodeStatus.INSPECTING) {
			throw new IllegalStateException(
				"只有验收中的节点才能标记未通过，当前状态: " + this.status);
		}
		this.status = InspectionNodeStatus.FAILED;
	}
}
