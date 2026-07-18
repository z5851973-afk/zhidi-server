package com.zhidi.server.payment;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "支付", description = "支付订单创建、查询、回调与退款")
public class PaymentController {

	private final PaymentOrderService paymentOrderService;
	private final SettlementService settlementService;

	public PaymentController(PaymentOrderService paymentOrderService,
			SettlementService settlementService) {
		this.paymentOrderService = paymentOrderService;
		this.settlementService = settlementService;
	}

	@PostMapping("/api/v1/payment/orders")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主创建支付订单（HIRED 状态可用）")
	public ApiResponse<PaymentOrderResponse> createOrder(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody CreatePaymentOrderRequest request) {
		return ApiResponse.ok(
			paymentOrderService.createOrder(principal.userId(), request.bookingId()),
			traceId());
	}

	@GetMapping("/api/v1/payment/orders/{orderId}")
	@PreAuthorize("isAuthenticated()")
	@Operation(summary = "查询支付订单详情")
	public ApiResponse<PaymentOrderResponse> getOrder(
			@PathVariable UUID orderId) {
		return ApiResponse.ok(paymentOrderService.getOrder(orderId), traceId());
	}

	@GetMapping("/api/v1/payment/orders")
	@PreAuthorize("isAuthenticated()")
	@Operation(summary = "当前用户的支付订单列表（分页）")
	public ApiResponse<Page<PaymentOrderResponse>> listOrders(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size) {
		return ApiResponse.ok(
			paymentOrderService.listOrdersForUser(principal.userId(),
				PageRequest.of(page, size)),
			traceId());
	}

	@PostMapping("/api/v1/payment/callback")
	@Operation(summary = "支付回调（第三方支付成功后调用）")
	public ApiResponse<PaymentOrderResponse> paymentCallback(
			@Valid @RequestBody PaymentCallbackRequest request) {
		// TODO: 支付回调验签 — 必须完成以下步骤才能投入生产：
		// 1. 从请求头获取签名（如 X-WeChatPay-Signature / Alipay-Signature）
		// 2. 使用平台公钥或 MD5 密钥重新计算签名
		//    - 微信支付 V3：验签流程见 https://pay.weixin.qq.com/docs/merchant/development/interface-rules/signature-verification.html
		//    - 支付宝：验签流程见 https://opendocs.alipay.com/common/02kf5g
		// 3. 比较计算签名与请求头签名，不一致则返回 401 拒绝
		// 4. 验证订单号、金额与本地记录一致（防篡改）
		// 5. 幂等处理：同一 transaction_id 重复回调只返回已有结果
		PaymentOrderResponse order = paymentOrderService.markPaid(
			request.orderId(), request.transactionId(), request.paymentMethod());
		// 支付成功后自动创建结算记录
		settlementService.createForPayment(request.orderId());
		return ApiResponse.ok(order, traceId());
	}

	@PostMapping("/api/v1/payment/orders/{orderId}/refund")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主申请退款")
	public ApiResponse<PaymentOrderResponse> requestRefund(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID orderId,
			@Valid @RequestBody RefundRequest request) {
		return ApiResponse.ok(
			paymentOrderService.requestRefund(principal.userId(), orderId,
				request.reason()),
			traceId());
	}

	private static String traceId() {
		return MDC.get(TraceIdFilter.TRACE_ID_KEY);
	}

	// — 请求体 DTO —

	public record CreatePaymentOrderRequest(@NotBlank UUID bookingId) {}

	public record PaymentCallbackRequest(
		@NotBlank UUID orderId,
		@NotBlank String transactionId,
		@NotBlank String paymentMethod) {}

	public record RefundRequest(@NotBlank String reason) {}
}
