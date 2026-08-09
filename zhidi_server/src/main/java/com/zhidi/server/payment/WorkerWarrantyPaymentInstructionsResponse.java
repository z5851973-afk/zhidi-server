package com.zhidi.server.payment;

public record WorkerWarrantyPaymentInstructionsResponse(
	String accountName,
	String bankName,
	String bankAccount
) {}
