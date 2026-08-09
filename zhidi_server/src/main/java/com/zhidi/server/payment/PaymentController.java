package com.zhidi.server.payment;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
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
	private final OfflinePaymentInstructionsService offlinePaymentInstructions;

	public PaymentController(PaymentOrderService paymentOrderService,
			OfflinePaymentInstructionsService offlinePaymentInstructions) {
		this.paymentOrderService = paymentOrderService;
		this.offlinePaymentInstructions = offlinePaymentInstructions;
	}

	@PostMapping("/api/v1/payment/orders")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主创建支付订单（施工中或验收完成状态可用）")
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

	@GetMapping("/api/v1/payment/offline-instructions")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "读取本单工程款和平台服务费线下付款指引")
	public ApiResponse<OfflinePaymentInstructionsResponse> offlineInstructions(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@RequestParam UUID orderId) {
		return ApiResponse.ok(
			offlinePaymentInstructions.get(principal.userId(), orderId), traceId());
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

	@PostMapping("/api/v1/payment/orders/{orderId}/offline-payment-report")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主报告已完成线下付款（仍需工人确认收款）")
	public ApiResponse<PaymentOrderResponse> reportOfflinePayment(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID orderId,
			@Valid @RequestBody OfflinePaymentReportRequest request) {
		return ApiResponse.ok(paymentOrderService.reportOfflinePayment(
			principal.userId(), orderId, request.channel(), request.reference(),
			request.note()), traceId());
	}

	@PostMapping("/api/v1/payment/orders/{orderId}/receipt-confirmation")
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "工人确认实际收到线下款项")
	public ApiResponse<PaymentOrderResponse> confirmOfflineReceipt(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID orderId) {
		return ApiResponse.ok(paymentOrderService.confirmOfflineReceipt(
			principal.userId(), orderId), traceId());
	}

	@PostMapping("/api/v1/payment/orders/{orderId}/offline-split-report")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主一次提交工程款与平台服务费两笔线下付款信息")
	public ApiResponse<PaymentOrderResponse> reportSplitOfflinePayments(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID orderId,
			@Valid @RequestBody SplitOfflinePaymentReportRequest request) {
		return ApiResponse.ok(paymentOrderService.reportSplitOfflinePayments(
			principal.userId(), orderId,
			request.constructionChannel(), request.constructionReference(),
			request.platformFeeChannel(), request.platformFeeReference(),
			request.note()), traceId());
	}

	@PostMapping("/api/v1/payment/orders/{orderId}/construction-receipt-confirmation")
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "工人确认收到本单全额工程款")
	public ApiResponse<PaymentOrderResponse> confirmConstructionReceipt(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID orderId) {
		return ApiResponse.ok(paymentOrderService.confirmConstructionReceipt(
			principal.userId(), orderId), traceId());
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

	public record OfflinePaymentReportRequest(
		@NotBlank @Size(max = 32) String channel,
		@Size(max = 128) String reference,
		@Size(max = 300) String note) {}

	public record SplitOfflinePaymentReportRequest(
		@Size(max = 32) String constructionChannel,
		@Size(max = 128) String constructionReference,
		@Size(max = 32) String platformFeeChannel,
		@Size(max = 128) String platformFeeReference,
		@Size(max = 300) String note) {

		@AssertTrue(message = "至少提交一笔完整付款信息")
		public boolean isComponentSelectionValid() {
			boolean constructionAbsent = constructionChannel == null
				&& constructionReference == null;
			boolean platformFeeAbsent = platformFeeChannel == null
				&& platformFeeReference == null;
			boolean constructionComplete = hasText(constructionChannel)
				&& hasText(constructionReference);
			boolean platformFeeComplete = hasText(platformFeeChannel)
				&& hasText(platformFeeReference);
			return (constructionAbsent || constructionComplete)
				&& (platformFeeAbsent || platformFeeComplete)
				&& (constructionComplete || platformFeeComplete);
		}

		private static boolean hasText(String value) {
			return value != null && !value.isBlank();
		}
	}
}
