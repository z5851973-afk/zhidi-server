package com.zhidi.server.payment;

public enum PaymentOrderStatus {
	PENDING,
	OWNER_REPORTED_PAID,
	PAID,
	CANCELLED,
	REFUNDED,
	FAILED
}
