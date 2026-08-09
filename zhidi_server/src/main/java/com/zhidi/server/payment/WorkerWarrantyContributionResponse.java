package com.zhidi.server.payment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record WorkerWarrantyContributionResponse(
	UUID id,
	UUID workerUserId,
	UUID paymentOrderId,
	UUID bookingId,
	UUID afterSaleId,
	BigDecimal amountDue,
	WorkerWarrantyContributionStatus status,
	String paymentChannel,
	String paymentReference,
	Instant reportedAt,
	UUID verifiedBy,
	Instant verifiedAt,
	String rejectionReason,
	Instant createdAt,
	Instant updatedAt
) {
	static WorkerWarrantyContributionResponse from(
			WorkerWarrantyContribution contribution) {
		return new WorkerWarrantyContributionResponse(
			contribution.getId(), contribution.getWorkerUserId(),
			contribution.getPaymentOrderId(), contribution.getBookingId(),
			contribution.getAfterSaleId(),
			contribution.getAmountDue(), contribution.getStatus(),
			contribution.getPaymentChannel(), contribution.getPaymentReference(),
			contribution.getReportedAt(), contribution.getVerifiedBy(),
			contribution.getVerifiedAt(), contribution.getRejectionReason(),
			contribution.getCreatedAt(), contribution.getUpdatedAt());
	}
}
