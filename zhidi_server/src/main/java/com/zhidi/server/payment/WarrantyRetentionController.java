package com.zhidi.server.payment;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "质保金", description = "质保金冻结、扣减和释放")
public class WarrantyRetentionController {

	private final WarrantyRetentionService warrantyRetentionService;

	public WarrantyRetentionController(
			WarrantyRetentionService warrantyRetentionService) {
		this.warrantyRetentionService = warrantyRetentionService;
	}

	@GetMapping("/api/v1/warranty-retentions")
	@PreAuthorize("isAuthenticated()")
	@Operation(summary = "当前用户可见的质保金记录")
	public ApiResponse<List<WarrantyRetentionResponse>> listForUser(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(
			warrantyRetentionService.listForUser(principal.userId()), traceId());
	}

	@PostMapping("/api/v1/admin/warranty-retentions/{id}/release")
	@PreAuthorize("hasRole('ADMIN')")
	@Operation(summary = "管理员释放剩余质保金")
	public ApiResponse<WarrantyRetentionResponse> release(@PathVariable UUID id) {
		return ApiResponse.ok(warrantyRetentionService.release(id), traceId());
	}

	@PostMapping("/api/v1/admin/warranty-retentions/{id}/deduct")
	@PreAuthorize("hasRole('ADMIN')")
	@Operation(summary = "管理员按售后处理扣减质保金")
	public ApiResponse<WarrantyRetentionResponse> deduct(
			@PathVariable UUID id,
			@Valid @RequestBody DeductWarrantyRetentionRequest request) {
		return ApiResponse.ok(
			warrantyRetentionService.deduct(id, request.amount(), request.reason()),
			traceId());
	}

	private static String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}

	public record DeductWarrantyRetentionRequest(
		@NotNull @DecimalMin(value = "0.01") BigDecimal amount,
		@NotBlank String reason
	) {}
}
