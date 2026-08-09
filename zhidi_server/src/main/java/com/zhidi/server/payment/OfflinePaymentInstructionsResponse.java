package com.zhidi.server.payment;

import java.math.BigDecimal;
import java.util.UUID;

public record OfflinePaymentInstructionsResponse(
	UUID orderId,
	BigDecimal quoteAmount,
	BigDecimal platformFee,
	ConstructionPaymentInstruction constructionPayment,
	PlatformFeePaymentInstruction platformFeePayment
) {
	public record ConstructionPaymentInstruction(
		BigDecimal amount,
		String workerName,
		String contactAction
	) {}

	public record PlatformFeePaymentInstruction(
		BigDecimal amount,
		String accountName,
		String bankName,
		String bankAccount
	) {}
}
