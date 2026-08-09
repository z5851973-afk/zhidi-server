package com.zhidi.server.payment;

public enum PaymentOrderStatus {
	PENDING,
	PARTIALLY_REPORTED,
	UNDER_REVIEW,
	OWNER_REPORTED_PAID,
	PAID,
	CANCELLED,
	REFUNDED,
	FAILED
}
