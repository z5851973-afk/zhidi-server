package com.zhidi.server.payment;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "售后", description = "售后工单创建、查询与平台处理")
public class AfterSaleController {

	private final AfterSaleService afterSaleService;

	public AfterSaleController(AfterSaleService afterSaleService) {
		this.afterSaleService = afterSaleService;
	}

	@PostMapping("/api/v1/after-sales")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主创建售后申请")
	public ApiResponse<AfterSaleResponse> create(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody CreateAfterSaleRequest request) {
		return ApiResponse.ok(
			afterSaleService.create(request.bookingId(), principal.userId(),
				request.type(), request.reason(), request.evidence()),
			traceId());
	}

	@GetMapping("/api/v1/after-sales/{id}")
	@PreAuthorize("isAuthenticated()")
	@Operation(summary = "查询售后工单详情")
	public ApiResponse<AfterSaleResponse> getAfterSale(
			@PathVariable UUID id) {
		return ApiResponse.ok(afterSaleService.getAfterSale(id), traceId());
	}

	@GetMapping("/api/v1/after-sales")
	@PreAuthorize("isAuthenticated()")
	@Operation(summary = "当前用户的售后工单列表")
	public ApiResponse<List<AfterSaleResponse>> listForUser(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(
			afterSaleService.listForUser(principal.userId()), traceId());
	}

	@PutMapping("/api/v1/admin/after-sales/{id}/process")
	@PreAuthorize("hasRole('ADMIN')")
	@Operation(summary = "管理员处理售后工单")
	public ApiResponse<AfterSaleResponse> process(
			@PathVariable UUID id,
			@Valid @RequestBody ProcessAfterSaleRequest request) {
		return ApiResponse.ok(
			afterSaleService.process(id, request.resolution()), traceId());
	}

	private static String traceId() {
		return MDC.get(TraceIdFilter.TRACE_ID_KEY);
	}

	// — 请求体 DTO —

	public record CreateAfterSaleRequest(
		@NotNull UUID bookingId,
		@NotNull AfterSaleType type,
		@NotBlank String reason,
		String evidence) {}

	public record ProcessAfterSaleRequest(@NotBlank String resolution) {}
}
