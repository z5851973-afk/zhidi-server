package com.zhidi.server.payment;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "worker_warranty_contributions")
public class WorkerWarrantyContribution extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "payment_order_id", unique = true,
		updatable = false, columnDefinition = "BINARY(16)")
	private UUID paymentOrderId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "after_sale_id", unique = true, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID afterSaleId;

	@Column(name = "amount_due", nullable = false, precision = 12, scale = 2)
	private BigDecimal amountDue;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private WorkerWarrantyContributionStatus status;

	@Column(name = "payment_channel", length = 32)
	private String paymentChannel;

	@Column(name = "payment_reference", unique = true, length = 128)
	private String paymentReference;

	@Column(name = "reported_at")
	private Instant reportedAt;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "verified_by", columnDefinition = "BINARY(16)")
	private UUID verifiedBy;

	@Column(name = "verified_at")
	private Instant verifiedAt;

	@Column(name = "rejection_reason", length = 300)
	private String rejectionReason;

	protected WorkerWarrantyContribution() {}

	private WorkerWarrantyContribution(UUID workerUserId, UUID paymentOrderId,
			UUID bookingId, UUID afterSaleId, BigDecimal amountDue) {
		this.workerUserId = Objects.requireNonNull(workerUserId);
		boolean paidOrderSource = paymentOrderId != null && bookingId != null
			&& afterSaleId == null;
		boolean afterSaleSource = paymentOrderId == null && bookingId == null
			&& afterSaleId != null;
		if (!paidOrderSource && !afterSaleSource) {
			throw new IllegalArgumentException("质保金补充义务来源无效");
		}
		this.paymentOrderId = paymentOrderId;
		this.bookingId = bookingId;
		this.afterSaleId = afterSaleId;
		this.amountDue = WorkerWarrantyAccount.money(amountDue);
		if (this.amountDue.compareTo(BigDecimal.ZERO) <= 0) {
			throw new IllegalArgumentException("待补质保金必须大于0");
		}
		this.status = WorkerWarrantyContributionStatus.DUE;
	}

	public static WorkerWarrantyContribution create(UUID workerUserId,
			UUID paymentOrderId, UUID bookingId, BigDecimal amountDue) {
		return createForPaidOrder(
			workerUserId, paymentOrderId, bookingId, amountDue);
	}

	public static WorkerWarrantyContribution createForPaidOrder(
			UUID workerUserId, UUID paymentOrderId, UUID bookingId,
			BigDecimal amountDue) {
		return new WorkerWarrantyContribution(workerUserId, paymentOrderId,
			bookingId, null, amountDue);
	}

	public static WorkerWarrantyContribution createForAfterSaleDeduction(
			UUID workerUserId, UUID afterSaleId, BigDecimal amountDue) {
		return new WorkerWarrantyContribution(workerUserId, null, null,
			Objects.requireNonNull(afterSaleId), amountDue);
	}

	public void report(String channel, String reference) {
		if (status != WorkerWarrantyContributionStatus.DUE
				&& status != WorkerWarrantyContributionStatus.REJECTED) {
			throw new IllegalStateException("当前补充义务不能再次报备");
		}
		if (channel == null || channel.isBlank()
				|| reference == null || reference.isBlank()) {
			throw new IllegalArgumentException("付款方式和交易参考号不能为空");
		}
		this.paymentChannel = channel.trim();
		this.paymentReference = reference.trim();
		this.reportedAt = Instant.now();
		this.verifiedBy = null;
		this.verifiedAt = null;
		this.rejectionReason = null;
		this.status = WorkerWarrantyContributionStatus.REPORTED;
	}

	public void verify(UUID adminUserId) {
		if (status == WorkerWarrantyContributionStatus.VERIFIED) return;
		if (status != WorkerWarrantyContributionStatus.REPORTED) {
			throw new IllegalStateException("只有已报备质保金才能核验");
		}
		this.verifiedBy = Objects.requireNonNull(adminUserId);
		this.verifiedAt = Instant.now();
		this.rejectionReason = null;
		this.status = WorkerWarrantyContributionStatus.VERIFIED;
	}

	public void reject(UUID adminUserId, String reason) {
		if (status == WorkerWarrantyContributionStatus.REJECTED) return;
		if (status != WorkerWarrantyContributionStatus.REPORTED) {
			throw new IllegalStateException("只有已报备质保金才能驳回");
		}
		if (reason == null || reason.isBlank()) {
			throw new IllegalArgumentException("驳回原因不能为空");
		}
		this.verifiedBy = Objects.requireNonNull(adminUserId);
		this.verifiedAt = Instant.now();
		this.rejectionReason = reason.trim();
		this.status = WorkerWarrantyContributionStatus.REJECTED;
	}

	public UUID getWorkerUserId() { return workerUserId; }
	public UUID getPaymentOrderId() { return paymentOrderId; }
	public UUID getBookingId() { return bookingId; }
	public UUID getAfterSaleId() { return afterSaleId; }
	public UUID getSourceReferenceId() {
		return afterSaleId != null ? afterSaleId : paymentOrderId;
	}
	public BigDecimal getAmountDue() { return amountDue; }
	public WorkerWarrantyContributionStatus getStatus() { return status; }
	public String getPaymentChannel() { return paymentChannel; }
	public String getPaymentReference() { return paymentReference; }
	public Instant getReportedAt() { return reportedAt; }
	public UUID getVerifiedBy() { return verifiedBy; }
	public Instant getVerifiedAt() { return verifiedAt; }
	public String getRejectionReason() { return rejectionReason; }
}
