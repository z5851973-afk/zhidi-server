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
@Table(name = "payment_orders")
public class PaymentOrder extends BaseEntity {
	private static final BigDecimal PLATFORM_SERVICE_FEE_RATE =
		new BigDecimal("0.10");
	private static final BigDecimal WARRANTY_RETENTION_RATE =
		new BigDecimal("0.10");

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "owner_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID ownerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "quote_id", updatable = false, columnDefinition = "BINARY(16)")
	private UUID quoteId;

	@Column(nullable = false, precision = 12, scale = 2)
	private BigDecimal amount;

	@Column(name = "platform_fee", nullable = false, precision = 12, scale = 2)
	private BigDecimal platformFee;

	@Column(name = "worker_settlement", nullable = false, precision = 12, scale = 2)
	private BigDecimal workerSettlement;

	@Enumerated(EnumType.STRING)
	@Column(name = "funding_model", nullable = false, length = 40)
	private PaymentFundingModel fundingModel;

	@Column(name = "quote_amount", precision = 12, scale = 2)
	private BigDecimal quoteAmount;

	@Enumerated(EnumType.STRING)
	@Column(name = "construction_payment_status", nullable = false, length = 32)
	private PaymentComponentStatus constructionPaymentStatus;

	@Enumerated(EnumType.STRING)
	@Column(name = "platform_fee_status", nullable = false, length = 32)
	private PaymentComponentStatus platformFeeStatus;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private PaymentOrderStatus status;

	@Column(name = "payment_method", length = 32)
	private String paymentMethod;

	@Column(name = "transaction_id", length = 128)
	private String transactionId;

	@Column(name = "paid_at")
	private Instant paidAt;

	@Column(name = "owner_reported_paid_at")
	private Instant ownerReportedPaidAt;

	@Column(name = "offline_payment_channel", length = 32)
	private String offlinePaymentChannel;

	@Column(name = "payment_reference", length = 128)
	private String paymentReference;

	@Column(name = "owner_payment_note", length = 300)
	private String ownerPaymentNote;

	@Column(name = "construction_payment_channel", length = 32)
	private String constructionPaymentChannel;

	@Column(name = "construction_payment_reference", length = 128)
	private String constructionPaymentReference;

	@Column(name = "construction_reported_at")
	private Instant constructionReportedAt;

	@Column(name = "construction_confirmed_at")
	private Instant constructionConfirmedAt;

	@Column(name = "platform_fee_channel", length = 32)
	private String platformFeeChannel;

	@Column(name = "platform_fee_reference", length = 128)
	private String platformFeeReference;

	@Column(name = "platform_fee_reported_at")
	private Instant platformFeeReportedAt;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "platform_fee_verified_by", columnDefinition = "BINARY(16)")
	private UUID platformFeeVerifiedBy;

	@Column(name = "platform_fee_verified_at")
	private Instant platformFeeVerifiedAt;

	@Column(name = "platform_fee_rejection_reason", length = 300)
	private String platformFeeRejectionReason;

	@Column(name = "worker_confirmed_received_at")
	private Instant workerConfirmedReceivedAt;

	@Column(name = "refunded_at")
	private Instant refundedAt;

	protected PaymentOrder() {
	}

	private PaymentOrder(UUID bookingId, UUID ownerUserId, UUID workerUserId,
			UUID quoteId, BigDecimal quoteAmount,
			PaymentFundingModel fundingModel) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.quoteId = quoteId;
		BigDecimal normalizedQuoteAmount = Objects.requireNonNull(quoteAmount)
			.setScale(2, java.math.RoundingMode.HALF_UP);
		BigDecimal fee = normalizedQuoteAmount.multiply(PLATFORM_SERVICE_FEE_RATE).setScale(2,
			java.math.RoundingMode.HALF_UP);
		this.fundingModel = Objects.requireNonNull(fundingModel);
		this.quoteAmount = fundingModel == PaymentFundingModel.OFFLINE_SPLIT_V2
			? normalizedQuoteAmount : null;
		this.amount = normalizedQuoteAmount.add(fee);
		this.platformFee = fee;
		this.workerSettlement = fundingModel == PaymentFundingModel.OFFLINE_SPLIT_V2
			? normalizedQuoteAmount
			: normalizedQuoteAmount
				.subtract(calculateWarrantyRetention(normalizedQuoteAmount))
				.setScale(2, java.math.RoundingMode.HALF_UP);
		this.constructionPaymentStatus = PaymentComponentStatus.NOT_REPORTED;
		this.platformFeeStatus = PaymentComponentStatus.NOT_REPORTED;
		this.status = PaymentOrderStatus.PENDING;
	}

	public static PaymentOrder create(UUID bookingId, UUID ownerUserId,
			UUID workerUserId, UUID quoteId, BigDecimal amount) {
		return new PaymentOrder(bookingId, ownerUserId, workerUserId, quoteId, amount,
			PaymentFundingModel.LEGACY_OWNER_RETENTION);
	}

	public static PaymentOrder createOffline(UUID bookingId, UUID ownerUserId,
			UUID workerUserId, UUID quoteId, BigDecimal amount) {
		PaymentOrder order = new PaymentOrder(
			bookingId, ownerUserId, workerUserId, quoteId, amount,
			PaymentFundingModel.LEGACY_OWNER_RETENTION);
		order.paymentMethod = "OFFLINE";
		return order;
	}

	public static PaymentOrder createSplitOffline(UUID bookingId, UUID ownerUserId,
			UUID workerUserId, UUID quoteId, BigDecimal amount) {
		PaymentOrder order = new PaymentOrder(
			bookingId, ownerUserId, workerUserId, quoteId, amount,
			PaymentFundingModel.OFFLINE_SPLIT_V2);
		order.paymentMethod = "OFFLINE_SPLIT";
		return order;
	}

	public UUID getBookingId() { return bookingId; }
	public UUID getOwnerUserId() { return ownerUserId; }
	public UUID getWorkerUserId() { return workerUserId; }
	public UUID getQuoteId() { return quoteId; }
	public BigDecimal getAmount() { return amount; }
	public BigDecimal getPlatformFee() { return platformFee; }
	public BigDecimal getWorkerSettlement() { return workerSettlement; }
	public BigDecimal getWarrantyRetention() {
		if (fundingModel == PaymentFundingModel.OFFLINE_SPLIT_V2) {
			return BigDecimal.ZERO.setScale(2);
		}
		BigDecimal retained = amount
			.subtract(platformFee)
			.subtract(workerSettlement)
			.setScale(2, java.math.RoundingMode.HALF_UP);
		return retained.max(BigDecimal.ZERO.setScale(2));
	}
	public PaymentOrderStatus getStatus() { return status; }
	public PaymentFundingModel getFundingModel() { return fundingModel; }
	public BigDecimal getQuoteAmount() {
		return quoteAmount != null
			? quoteAmount
			: amount.subtract(platformFee).setScale(2,
				java.math.RoundingMode.HALF_UP);
	}
	public PaymentComponentStatus getConstructionPaymentStatus() {
		return constructionPaymentStatus;
	}
	public PaymentComponentStatus getPlatformFeeStatus() { return platformFeeStatus; }
	public String getPaymentMethod() { return paymentMethod; }
	public String getTransactionId() { return transactionId; }
	public Instant getPaidAt() { return paidAt; }
	public Instant getOwnerReportedPaidAt() { return ownerReportedPaidAt; }
	public String getOfflinePaymentChannel() { return offlinePaymentChannel; }
	public String getPaymentReference() { return paymentReference; }
	public String getOwnerPaymentNote() { return ownerPaymentNote; }
	public String getConstructionPaymentChannel() { return constructionPaymentChannel; }
	public String getConstructionPaymentReference() { return constructionPaymentReference; }
	public Instant getConstructionReportedAt() { return constructionReportedAt; }
	public Instant getConstructionConfirmedAt() { return constructionConfirmedAt; }
	public String getPlatformFeeChannel() { return platformFeeChannel; }
	public String getPlatformFeeReference() { return platformFeeReference; }
	public Instant getPlatformFeeReportedAt() { return platformFeeReportedAt; }
	public UUID getPlatformFeeVerifiedBy() { return platformFeeVerifiedBy; }
	public Instant getPlatformFeeVerifiedAt() { return platformFeeVerifiedAt; }
	public String getPlatformFeeRejectionReason() { return platformFeeRejectionReason; }
	public boolean canReportConstructionPayment() {
		return constructionPaymentStatus == PaymentComponentStatus.NOT_REPORTED
			|| constructionPaymentStatus == PaymentComponentStatus.REJECTED;
	}
	public boolean canReportPlatformFee() {
		return platformFeeStatus == PaymentComponentStatus.NOT_REPORTED
			|| platformFeeStatus == PaymentComponentStatus.REJECTED;
	}
	public Instant getWorkerConfirmedReceivedAt() { return workerConfirmedReceivedAt; }
	public Instant getRefundedAt() { return refundedAt; }

	public void reportOfflinePayment(String channel, String reference, String note) {
		if (this.status != PaymentOrderStatus.PENDING) {
			throw new IllegalStateException("只有待付款订单才能报告线下付款");
		}
		if (!"OFFLINE".equals(this.paymentMethod)) {
			throw new IllegalStateException("该订单不是线下付款订单");
		}
		if (channel == null || channel.isBlank()) {
			throw new IllegalArgumentException("付款方式不能为空");
		}
		this.offlinePaymentChannel = channel.trim();
		this.paymentReference = normalize(reference);
		this.ownerPaymentNote = normalize(note);
		this.ownerReportedPaidAt = Instant.now();
		this.status = PaymentOrderStatus.OWNER_REPORTED_PAID;
	}

	public void confirmOfflineReceipt() {
		if (this.status != PaymentOrderStatus.OWNER_REPORTED_PAID) {
			throw new IllegalStateException("业主报告付款后才能确认收款");
		}
		Instant now = Instant.now();
		this.workerConfirmedReceivedAt = now;
		this.paidAt = now;
		this.status = PaymentOrderStatus.PAID;
	}

	public void reportSplitOfflinePayments(
			String constructionChannel, String constructionReference,
			String platformFeeChannel, String platformFeeReference, String note) {
		validateSplitOfflinePaymentReport(
			constructionChannel, constructionReference,
			platformFeeChannel, platformFeeReference);

		boolean constructionRequested = componentRequested(
			constructionChannel, constructionReference);
		boolean platformFeeRequested = componentRequested(
			platformFeeChannel, platformFeeReference);
		Instant now = Instant.now();
		boolean changed = false;
		if (constructionRequested && canReportConstructionPayment()) {
			this.constructionPaymentChannel = constructionChannel.trim();
			this.constructionPaymentReference = constructionReference.trim();
			this.constructionReportedAt = now;
			this.constructionPaymentStatus = PaymentComponentStatus.REPORTED;
			changed = true;
		}
		if (platformFeeRequested && canReportPlatformFee()) {
			this.platformFeeChannel = platformFeeChannel.trim();
			this.platformFeeReference = platformFeeReference.trim();
			this.platformFeeReportedAt = now;
			this.platformFeeStatus = PaymentComponentStatus.REPORTED;
			this.platformFeeRejectionReason = null;
			changed = true;
		}
		if (!changed) return;
		if (note != null) this.ownerPaymentNote = normalize(note);
		this.ownerReportedPaidAt = now;
		refreshOverallStatus();
	}

	void validateSplitOfflinePaymentReport(
			String constructionChannel, String constructionReference,
			String platformFeeChannel, String platformFeeReference) {
		requireSplitFundingModel();
		if (this.status == PaymentOrderStatus.PAID
				|| this.status == PaymentOrderStatus.CANCELLED
				|| this.status == PaymentOrderStatus.REFUNDED) {
			throw new IllegalStateException("当前订单状态不能报告线下付款");
		}
		boolean constructionRequested = componentRequested(
			constructionChannel, constructionReference);
		boolean platformFeeRequested = componentRequested(
			platformFeeChannel, platformFeeReference);
		if (!constructionRequested && !platformFeeRequested) {
			throw new IllegalArgumentException("至少提交一笔付款信息");
		}
		validateCompleteComponent("工程款", constructionRequested,
			constructionChannel, constructionReference);
		validateCompleteComponent("平台服务费", platformFeeRequested,
			platformFeeChannel, platformFeeReference);
		validateImmutableComponent("工程款", constructionRequested,
			constructionPaymentStatus, constructionPaymentChannel,
			constructionPaymentReference, constructionChannel,
			constructionReference);
		validateImmutableComponent("平台服务费", platformFeeRequested,
			platformFeeStatus, this.platformFeeChannel, this.platformFeeReference,
			platformFeeChannel, platformFeeReference);
	}

	private static boolean componentRequested(String channel, String reference) {
		return channel != null || reference != null;
	}

	private static void validateCompleteComponent(String label,
			boolean requested, String channel, String reference) {
		if (requested && (channel == null || channel.isBlank()
				|| reference == null || reference.isBlank())) {
			throw new IllegalArgumentException(
				label + "付款方式和交易参考号必须同时填写");
		}
	}

	private static void validateImmutableComponent(String label, boolean requested,
			PaymentComponentStatus status, String savedChannel,
			String savedReference, String requestedChannel,
			String requestedReference) {
		if (!requested || status == PaymentComponentStatus.NOT_REPORTED
				|| status == PaymentComponentStatus.REJECTED) {
			return;
		}
		if (!Objects.equals(savedChannel, requestedChannel.trim())
				|| !Objects.equals(savedReference, requestedReference.trim())) {
			throw new IllegalStateException(label + "已提交核验，不能重复修改");
		}
	}

	public void confirmConstructionReceipt() {
		requireSplitFundingModel();
		if (constructionPaymentStatus == PaymentComponentStatus.CONFIRMED) {
			return;
		}
		if (constructionPaymentStatus != PaymentComponentStatus.REPORTED) {
			throw new IllegalStateException("业主报告工程款后才能确认收款");
		}
		this.constructionPaymentStatus = PaymentComponentStatus.CONFIRMED;
		this.constructionConfirmedAt = Instant.now();
		this.workerConfirmedReceivedAt = this.constructionConfirmedAt;
		refreshOverallStatus();
	}

	public void verifyPlatformFee(boolean approved, UUID adminUserId,
			String rejectionReason) {
		requireSplitFundingModel();
		Objects.requireNonNull(adminUserId, "adminUserId");
		if (approved && platformFeeStatus == PaymentComponentStatus.VERIFIED) {
			return;
		}
		if (!approved && platformFeeStatus == PaymentComponentStatus.REJECTED) {
			return;
		}
		if (platformFeeStatus != PaymentComponentStatus.REPORTED) {
			throw new IllegalStateException("业主报告平台服务费后才能核验");
		}
		if (approved) {
			this.platformFeeStatus = PaymentComponentStatus.VERIFIED;
			this.platformFeeVerifiedBy = adminUserId;
			this.platformFeeVerifiedAt = Instant.now();
			this.platformFeeRejectionReason = null;
		} else {
			if (rejectionReason == null || rejectionReason.isBlank()) {
				throw new IllegalArgumentException("驳回原因不能为空");
			}
			this.platformFeeStatus = PaymentComponentStatus.REJECTED;
			this.platformFeeRejectionReason = rejectionReason.trim();
		}
		refreshOverallStatus();
	}

	private void refreshOverallStatus() {
		if (constructionPaymentStatus == PaymentComponentStatus.CONFIRMED
				&& platformFeeStatus == PaymentComponentStatus.VERIFIED) {
			this.status = PaymentOrderStatus.PAID;
			if (this.paidAt == null) this.paidAt = Instant.now();
			return;
		}
		if (constructionPaymentStatus == PaymentComponentStatus.REJECTED
				|| platformFeeStatus == PaymentComponentStatus.REJECTED) {
			this.status = PaymentOrderStatus.PARTIALLY_REPORTED;
			return;
		}
		if (constructionPaymentStatus != PaymentComponentStatus.NOT_REPORTED
				&& platformFeeStatus != PaymentComponentStatus.NOT_REPORTED) {
			this.status = PaymentOrderStatus.UNDER_REVIEW;
			return;
		}
		if (constructionPaymentStatus != PaymentComponentStatus.NOT_REPORTED
				|| platformFeeStatus != PaymentComponentStatus.NOT_REPORTED) {
			this.status = PaymentOrderStatus.PARTIALLY_REPORTED;
			return;
		}
		this.status = PaymentOrderStatus.PENDING;
	}

	private void requireSplitFundingModel() {
		if (fundingModel != PaymentFundingModel.OFFLINE_SPLIT_V2) {
			throw new IllegalStateException("该订单不使用拆分线下付款流程");
		}
	}

	private static String normalize(String value) {
		return value == null || value.isBlank() ? null : value.trim();
	}

	private static BigDecimal calculateWarrantyRetention(BigDecimal amount) {
		return amount.multiply(WARRANTY_RETENTION_RATE)
			.setScale(2, java.math.RoundingMode.HALF_UP);
	}

	public void markPaid(String transactionId, String paymentMethod) {
		this.status = PaymentOrderStatus.PAID;
		this.transactionId = transactionId;
		this.paymentMethod = paymentMethod;
		this.paidAt = Instant.now();
	}

	public void markRefunded() {
		this.status = PaymentOrderStatus.REFUNDED;
		this.refundedAt = Instant.now();
	}

	public void cancel() {
		this.status = PaymentOrderStatus.CANCELLED;
	}

	public void markFailed() {
		this.status = PaymentOrderStatus.FAILED;
	}
}
