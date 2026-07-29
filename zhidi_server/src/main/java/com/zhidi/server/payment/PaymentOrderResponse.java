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
	PaymentOrderStatus status,
	String paymentMethod,
	String transactionId,
	Instant paidAt,
	Instant ownerReportedPaidAt,
	String offlinePaymentChannel,
	String paymentReference,
	String ownerPaymentNote,
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
			order.getStatus(), order.getPaymentMethod(),
			order.getTransactionId(), order.getPaidAt(),
			order.getOwnerReportedPaidAt(),
			order.getOfflinePaymentChannel(),
			order.getPaymentReference(), order.getOwnerPaymentNote(),
			order.getWorkerConfirmedReceivedAt(),
			order.getRefundedAt(),
			order.getCreatedAt(), order.getUpdatedAt());
	}
}
