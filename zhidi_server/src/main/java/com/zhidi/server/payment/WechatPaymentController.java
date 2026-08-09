package com.zhidi.server.payment;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import com.zhidi.server.payment.provider.PaymentIntent;
import com.zhidi.server.payment.provider.PaymentProvider;
import io.swagger.v3.oas.annotations.Operation;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class WechatPaymentController {

	private final PaymentProvider wechatPaymentProvider;

	public WechatPaymentController(PaymentProvider wechatPaymentProvider) {
		this.wechatPaymentProvider = wechatPaymentProvider;
	}

	@PostMapping("/api/v1/payment/orders/{id}/wechat-intent")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "创建微信支付意图；未配置商户渠道时明确返回503")
	public ApiResponse<PaymentIntent> createIntent(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID id) {
		return ApiResponse.ok(
			wechatPaymentProvider.createIntent(principal.userId(), id), traceId());
	}

	private static String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
