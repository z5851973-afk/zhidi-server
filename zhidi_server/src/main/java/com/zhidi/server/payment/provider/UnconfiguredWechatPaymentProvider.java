package com.zhidi.server.payment.provider;

import com.zhidi.server.common.error.BusinessException;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class UnconfiguredWechatPaymentProvider implements PaymentProvider {

	@Override
	public PaymentIntent createIntent(UUID ownerUserId, UUID paymentOrderId) {
		throw unavailable();
	}

	@Override
	public PaymentCallbackResult verifyCallback(String headers, String body) {
		throw unavailable();
	}

	@Override
	public void requestRefund(UUID paymentOrderId, String reason) {
		throw unavailable();
	}

	private BusinessException unavailable() {
		return new BusinessException(HttpStatus.SERVICE_UNAVAILABLE,
			"PAYMENT_PROVIDER_NOT_CONFIGURED", "微信支付渠道尚未配置");
	}
}
