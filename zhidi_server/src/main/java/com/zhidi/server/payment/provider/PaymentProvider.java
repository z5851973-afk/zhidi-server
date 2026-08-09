package com.zhidi.server.payment.provider;

import java.util.UUID;

public interface PaymentProvider {
	PaymentIntent createIntent(UUID ownerUserId, UUID paymentOrderId);
	PaymentCallbackResult verifyCallback(String headers, String body);
	void requestRefund(UUID paymentOrderId, String reason);
}
