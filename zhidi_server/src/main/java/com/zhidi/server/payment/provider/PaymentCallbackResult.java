package com.zhidi.server.payment.provider;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record PaymentCallbackResult(
	UUID paymentOrderId,
	String providerTransactionId,
	BigDecimal paidAmount,
	Instant paidAt,
	boolean signatureVerified
) {}
