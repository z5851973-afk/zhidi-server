package com.zhidi.server.payment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record PaymentOrderResponse(
	UUID id,
	UUID bookingId,
	UUID ownerUserId,
	UUID workerUserId,
	UUID quoteId,
	BigDecimal amount,
	BigDecimal platformFee,
	BigDecimal workerSettlement,
	BigDecimal warrantyRetention,
	PaymentFundingModel fundingModel,
	BigDecimal quoteAmount,
	PaymentComponentStatus constructionPaymentStatus,
	PaymentComponentStatus platformFeeStatus,
	PaymentOrderStatus status,
	String paymentMethod,
	String transactionId,
	Instant paidAt,
	Instant ownerReportedPaidAt,
	String offlinePaymentChannel,
	String paymentReference,
	String ownerPaymentNote,
	String constructionPaymentChannel,
	String constructionPaymentReference,
	Instant constructionReportedAt,
	Instant constructionConfirmedAt,
	String platformFeeChannel,
	String platformFeeReference,
	Instant platformFeeReportedAt,
	UUID platformFeeVerifiedBy,
	Instant platformFeeVerifiedAt,
	String platformFeeRejectionReason,
	Instant workerConfirmedReceivedAt,
	Instant refundedAt,
	Instant createdAt,
	Instant updatedAt
) {

	public static PaymentOrderResponse from(PaymentOrder order) {
		return new PaymentOrderResponse(
			order.getId(), order.getBookingId(),
			order.getOwnerUserId(), order.getWorkerUserId(),
			order.getQuoteId(), order.getAmount(),
			order.getPlatformFee(), order.getWorkerSettlement(),
			order.getWarrantyRetention(),
			order.getFundingModel(), order.getQuoteAmount(),
			order.getConstructionPaymentStatus(), order.getPlatformFeeStatus(),
			order.getStatus(), order.getPaymentMethod(),
			order.getTransactionId(), order.getPaidAt(),
			order.getOwnerReportedPaidAt(),
			order.getOfflinePaymentChannel(),
			order.getPaymentReference(), order.getOwnerPaymentNote(),
			order.getConstructionPaymentChannel(),
			order.getConstructionPaymentReference(),
			order.getConstructionReportedAt(),
			order.getConstructionConfirmedAt(),
			order.getPlatformFeeChannel(), order.getPlatformFeeReference(),
			order.getPlatformFeeReportedAt(), order.getPlatformFeeVerifiedBy(),
			order.getPlatformFeeVerifiedAt(),
			order.getPlatformFeeRejectionReason(),
			order.getWorkerConfirmedReceivedAt(),
			order.getRefundedAt(),
			order.getCreatedAt(), order.getUpdatedAt());
	}
}
