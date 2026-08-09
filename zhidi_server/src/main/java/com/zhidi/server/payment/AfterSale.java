package com.zhidi.server.payment;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "after_sales")
public class AfterSale extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "owner_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID ownerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private AfterSaleType type;

	@Column(nullable = false, columnDefinition = "TEXT")
	private String reason;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "JSON")
	private List<String> evidence;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private AfterSaleStatus status;

	@Column(columnDefinition = "TEXT")
	private String resolution;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "warranty_retention_id", columnDefinition = "BINARY(16)")
	private UUID warrantyRetentionId;

	@Column(name = "warranty_deduction_amount", precision = 12, scale = 2)
	private BigDecimal warrantyDeductionAmount;

	@Column(name = "accepted_at")
	private Instant acceptedAt;

	@Column(name = "due_at", nullable = false)
	private Instant dueAt;

	@Column(name = "resolved_at")
	private Instant resolvedAt;

	@Column(name = "closed_at")
	private Instant closedAt;

	@Column(name = "last_activity_at", nullable = false)
	private Instant lastActivityAt;

	protected AfterSale() {
	}

	private AfterSale(UUID bookingId, UUID ownerUserId, UUID workerUserId,
			AfterSaleType type, String reason, List<String> evidenceUrls) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.type = Objects.requireNonNull(type);
		this.reason = Objects.requireNonNull(reason);
		this.evidence = evidenceUrls == null ? List.of() : List.copyOf(evidenceUrls);
		this.status = AfterSaleStatus.OPEN;
		Instant now = Instant.now();
		this.lastActivityAt = now;
		this.dueAt = now.plus(Duration.ofHours(72));
	}

	/** @deprecated Use the worker-snapshot factory for persisted tickets. */
	@Deprecated
	public static AfterSale create(UUID bookingId, UUID ownerUserId,
			AfterSaleType type, String reason, String evidence) {
		return new AfterSale(bookingId, ownerUserId, ownerUserId, type, reason,
			evidence == null || evidence.isBlank() ? List.of() : List.of(evidence));
	}

	public static AfterSale create(UUID bookingId, UUID ownerUserId,
			UUID workerUserId, AfterSaleType type, String reason,
			List<String> evidenceUrls) {
		return new AfterSale(bookingId, ownerUserId, workerUserId, type, reason,
			evidenceUrls);
	}

	public UUID getBookingId() { return bookingId; }
	public UUID getOwnerUserId() { return ownerUserId; }
	public UUID getWorkerUserId() { return workerUserId; }
	public AfterSaleType getType() { return type; }
	public String getReason() { return reason; }
	public List<String> getEvidenceUrls() {
		return evidence == null ? List.of() : List.copyOf(evidence);
	}
	public AfterSaleStatus getStatus() { return status; }
	public String getResolution() { return resolution; }
	public UUID getWarrantyRetentionId() { return warrantyRetentionId; }
	public BigDecimal getWarrantyDeductionAmount() {
		return warrantyDeductionAmount;
	}
	public Instant getAcceptedAt() { return acceptedAt; }
	public Instant getDueAt() { return dueAt; }
	public Instant getResolvedAt() { return resolvedAt; }
	public Instant getClosedAt() { return closedAt; }
	public Instant getLastActivityAt() { return lastActivityAt; }

	public void process(String resolution) {
		this.status = AfterSaleStatus.RESOLVED;
		this.resolution = resolution;
		Instant now = Instant.now();
		this.resolvedAt = now;
		this.lastActivityAt = now;
	}

	public void process(String resolution, UUID warrantyRetentionId,
			BigDecimal warrantyDeductionAmount) {
		process(resolution);
		this.warrantyRetentionId = warrantyRetentionId;
		this.warrantyDeductionAmount = warrantyDeductionAmount;
	}

	public void processWithWarrantyDeduction(String resolution,
			BigDecimal warrantyDeductionAmount) {
		process(resolution);
		this.warrantyRetentionId = null;
		this.warrantyDeductionAmount = warrantyDeductionAmount;
	}

	public void markPlatformProcessing() {
		if (this.status != AfterSaleStatus.OPEN) {
			throw new IllegalStateException("只有待处理工单才能受理");
		}
		this.status = AfterSaleStatus.PLATFORM_PROCESSING;
		Instant now = Instant.now();
		this.acceptedAt = now;
		this.lastActivityAt = now;
	}

	public void close() {
		if (this.status != AfterSaleStatus.RESOLVED) {
			throw new IllegalStateException("只有已解决工单才能关闭");
		}
		this.status = AfterSaleStatus.CLOSED;
		Instant now = Instant.now();
		this.closedAt = now;
		this.lastActivityAt = now;
	}

	public void touch() {
		this.lastActivityAt = Instant.now();
	}
}
