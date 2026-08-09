package com.zhidi.server.payment;

import com.zhidi.server.audit.OperationLog;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/payment-orders")
@PreAuthorize("hasRole('ADMIN')")
public class AdminPaymentController {

	private final PaymentOrderService paymentOrderService;
	private final OperationLogRepository operationLogs;

	public AdminPaymentController(PaymentOrderService paymentOrderService,
			OperationLogRepository operationLogs) {
		this.paymentOrderService = paymentOrderService;
		this.operationLogs = operationLogs;
	}

	@GetMapping
	public ApiResponse<Page<PaymentOrderResponse>> list(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size,
			@RequestParam(required = false) String platformFeeStatus) {
		if (page < 0 || size < 1 || size > 100) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_PAGE", "page 必须大于等于0，size必须在1到100之间");
		}
		PaymentComponentStatus status = parseStatus(platformFeeStatus);
		return ApiResponse.ok(paymentOrderService.listForAdmin(status,
			PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"))),
			traceId());
	}

	@PostMapping("/{orderId}/platform-fee-verification")
	public ApiResponse<PaymentOrderResponse> verifyPlatformFee(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID orderId,
			@Valid @RequestBody VerifyPlatformFeeRequest request) {
		PaymentOrderResponse response = paymentOrderService.verifyPlatformFee(
			principal.userId(), orderId, request.approved(), request.reason());
		String action = request.approved()
			? "ADMIN_PLATFORM_FEE_APPROVE" : "ADMIN_PLATFORM_FEE_REJECT";
		String reason = request.reason() == null
			? "" : request.reason().replace("\\", "\\\\").replace("\"", "\\\"");
		operationLogs.save(OperationLog.success(
			principal.userId(), action, "PAYMENT_ORDER", orderId.toString(), traceId(),
			"{\"approved\":" + request.approved()
				+ ",\"reason\":\"" + reason + "\"}"));
		return ApiResponse.ok(response, traceId());
	}

	private PaymentComponentStatus parseStatus(String value) {
		if (value == null || value.isBlank()) return null;
		try {
			return PaymentComponentStatus.valueOf(value.trim().toUpperCase());
		} catch (IllegalArgumentException ex) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_PLATFORM_FEE_STATUS", "平台服务费状态无效");
		}
	}

	private static String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}

	public record VerifyPlatformFeeRequest(
		@NotNull Boolean approved,
		@Size(max = 300) String reason) {}
}
