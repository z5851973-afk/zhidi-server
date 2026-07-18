package com.zhidi.server.payment;

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

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private AfterSaleType type;

	@Column(nullable = false, columnDefinition = "TEXT")
	private String reason;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "JSON")
	private String evidence;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private AfterSaleStatus status;

	@Column(columnDefinition = "TEXT")
	private String resolution;

	protected AfterSale() {
	}

	private AfterSale(UUID bookingId, UUID ownerUserId, AfterSaleType type,
			String reason, String evidence) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		this.type = Objects.requireNonNull(type);
		this.reason = Objects.requireNonNull(reason);
		this.evidence = evidence;
		this.status = AfterSaleStatus.OPEN;
	}

	public static AfterSale create(UUID bookingId, UUID ownerUserId,
			AfterSaleType type, String reason, String evidence) {
		return new AfterSale(bookingId, ownerUserId, type, reason, evidence);
	}

	public UUID getBookingId() { return bookingId; }
	public UUID getOwnerUserId() { return ownerUserId; }
	public AfterSaleType getType() { return type; }
	public String getReason() { return reason; }
	public String getEvidence() { return evidence; }
	public AfterSaleStatus getStatus() { return status; }
	public String getResolution() { return resolution; }

	public void process(String resolution) {
		this.status = AfterSaleStatus.RESOLVED;
		this.resolution = resolution;
	}

	public void markPlatformProcessing() {
		this.status = AfterSaleStatus.PLATFORM_PROCESSING;
	}

	public void close() {
		this.status = AfterSaleStatus.CLOSED;
	}
}
