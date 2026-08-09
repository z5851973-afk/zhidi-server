package com.zhidi.server.payment;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@PreAuthorize("hasRole('WORKER')")
public class WorkerWarrantyAccountController {

	private final WorkerWarrantyAccountService service;
	private final OfflinePaymentProperties paymentProperties;

	public WorkerWarrantyAccountController(WorkerWarrantyAccountService service,
			OfflinePaymentProperties paymentProperties) {
		this.service = service;
		this.paymentProperties = paymentProperties;
	}

	@GetMapping("/api/v1/worker-warranty/account")
	public ApiResponse<WorkerWarrantyAccountResponse> account(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(service.getAccount(principal.userId()), traceId());
	}

	@GetMapping("/api/v1/worker-warranty/contributions")
	public ApiResponse<List<WorkerWarrantyContributionResponse>> contributions(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(
			service.listContributions(principal.userId()), traceId());
	}

	@PostMapping("/api/v1/worker-warranty/account/top-up-obligation")
	public ApiResponse<WorkerWarrantyContributionResponse> topUpObligation(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(
			service.getOrCreateTopUpObligation(principal.userId()), traceId());
	}

	@PostMapping("/api/v1/worker-warranty/contributions/{id}/report")
	public ApiResponse<WorkerWarrantyContributionResponse> report(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID id,
			@Valid @RequestBody ReportContributionRequest request) {
		return ApiResponse.ok(service.reportContributionResponse(
			principal.userId(), id, request.channel(), request.reference()), traceId());
	}

	@PostMapping("/api/v1/worker-warranty/account/release-request")
	public ApiResponse<WorkerWarrantyAccountResponse> requestRelease(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(
			service.requestRelease(principal.userId()), traceId());
	}

	@GetMapping("/api/v1/worker-warranty/payment-instructions")
	public ApiResponse<WorkerWarrantyPaymentInstructionsResponse> paymentInstructions() {
		if (!paymentProperties.hasWarrantyAccount()) {
			throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE,
				"WARRANTY_PAYMENT_INSTRUCTIONS_NOT_CONFIGURED",
				"工人质保金收款账户尚未配置");
		}
		return ApiResponse.ok(new WorkerWarrantyPaymentInstructionsResponse(
			paymentProperties.warrantyAccountName(),
			paymentProperties.warrantyBankName(),
			paymentProperties.warrantyBankAccount()), traceId());
	}

	private static String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}

	public record ReportContributionRequest(
		@NotBlank @Size(max = 32) String channel,
		@NotBlank @Size(max = 128) String reference
	) {}
}
