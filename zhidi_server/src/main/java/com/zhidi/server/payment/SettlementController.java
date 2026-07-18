package com.zhidi.server.payment;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "结算", description = "工人结算记录查询与管理员结算操作")
public class SettlementController {

	private final SettlementService settlementService;

	public SettlementController(SettlementService settlementService) {
		this.settlementService = settlementService;
	}

	@GetMapping("/api/v1/settlements")
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "工人查看自己的结算记录")
	public ApiResponse<List<SettlementResponse>> listForWorker(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(
			settlementService.listForWorker(principal.userId()), traceId());
	}

	@PutMapping("/api/v1/admin/settlements/{id}/settleable")
	@PreAuthorize("hasRole('ADMIN')")
	@Operation(summary = "管理员标记可结算")
	public ApiResponse<SettlementResponse> markSettleable(
			@PathVariable UUID id) {
		return ApiResponse.ok(settlementService.markSettleable(id), traceId());
	}

	@PutMapping("/api/v1/admin/settlements/{id}/settle")
	@PreAuthorize("hasRole('ADMIN')")
	@Operation(summary = "管理员标记已结算")
	public ApiResponse<SettlementResponse> markSettled(
			@PathVariable UUID id) {
		return ApiResponse.ok(settlementService.markSettled(id), traceId());
	}

	@PutMapping("/api/v1/admin/settlements/{id}/freeze")
	@PreAuthorize("hasRole('ADMIN')")
	@Operation(summary = "管理员冻结结算")
	public ApiResponse<SettlementResponse> freeze(
			@PathVariable UUID id,
			@Valid @RequestBody FreezeRequest request) {
		return ApiResponse.ok(settlementService.freeze(id, request.reason()), traceId());
	}

	private static String traceId() {
		return MDC.get(TraceIdFilter.TRACE_ID_KEY);
	}

	public record FreezeRequest(@NotBlank String reason) {}
}
