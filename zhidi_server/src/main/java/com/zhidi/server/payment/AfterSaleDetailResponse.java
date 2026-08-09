package com.zhidi.server.payment;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record AfterSaleDetailResponse(
	AfterSaleResponse ticket,
	OrderContext context,
	List<AfterSaleEventResponse> timeline
) {
	public record OrderContext(
		UUID bookingId,
		String bookingStatus,
		String trade,
		String ownerName,
		String workerName,
		String serviceCity,
		String serviceAddress,
		UUID quoteId,
		BigDecimal quoteAmount,
		UUID paymentOrderId,
		BigDecimal paymentAmount,
		String paymentStatus,
		InspectionSummary inspection
	) {}

	public record InspectionSummary(
		String status,
		int passedCount,
		int totalCount
	) {}
}
