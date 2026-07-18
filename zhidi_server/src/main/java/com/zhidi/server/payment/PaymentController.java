package com.zhidi.server.payment;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
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

	public PaymentController(PaymentOrderService paymentOrderService) {
		this.paymentOrderService = paymentOrderService;
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
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID orderId) {
		return ApiResponse.ok(
			paymentOrderService.getOrder(principal.userId(), orderId), traceId());
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
		throw new com.zhidi.server.common.error.BusinessException(
			org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE,
			"PAYMENT_PROVIDER_NOT_CONFIGURED", "支付渠道尚未开通");
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
		return MDC.get(TraceIdFilter.MDC_KEY);
	}

	// — 请求体 DTO —

	public record CreatePaymentOrderRequest(@NotNull UUID bookingId) {}

	public record PaymentCallbackRequest(
		@NotNull UUID orderId,
		@NotBlank String transactionId,
		@NotBlank String paymentMethod) {}

	public record RefundRequest(@NotBlank String reason) {}
}
