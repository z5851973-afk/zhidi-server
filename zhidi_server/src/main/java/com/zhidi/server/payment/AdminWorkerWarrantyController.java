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
@RequestMapping("/api/v1/admin/worker-warranty")
@PreAuthorize("hasRole('ADMIN')")
public class AdminWorkerWarrantyController {

	private final WorkerWarrantyAccountService service;
	private final WorkerWarrantyReleaseService releases;
	private final OperationLogRepository operationLogs;

	public AdminWorkerWarrantyController(WorkerWarrantyAccountService service,
			WorkerWarrantyReleaseService releases,
			OperationLogRepository operationLogs) {
		this.service = service;
		this.releases = releases;
		this.operationLogs = operationLogs;
	}

	@GetMapping("/contributions")
	public ApiResponse<Page<WorkerWarrantyContributionResponse>> contributions(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size,
			@RequestParam(required = false) String status) {
		if (page < 0 || size < 1 || size > 100) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_PAGE", "page 必须大于等于0，size必须在1到100之间");
		}
		return ApiResponse.ok(service.listContributionsForAdmin(
			parseStatus(status), PageRequest.of(page, size,
				Sort.by(Sort.Direction.DESC, "createdAt"))), traceId());
	}

	@PostMapping("/contributions/{id}/verification")
	public ApiResponse<WorkerWarrantyContributionResponse> verify(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID id,
			@Valid @RequestBody VerifyContributionRequest request) {
		WorkerWarrantyContributionResponse response =
			service.verifyContributionResponse(
				principal.userId(), id, request.approved(), request.reason());
		String action = request.approved()
			? "ADMIN_WORKER_WARRANTY_APPROVE"
			: "ADMIN_WORKER_WARRANTY_REJECT";
		String reason = json(request.reason());
		operationLogs.save(OperationLog.success(
			principal.userId(), action, "WORKER_WARRANTY_CONTRIBUTION",
			id.toString(), traceId(),
			"{\"approved\":" + request.approved()
				+ ",\"amount\":\"" + response.amountDue()
				+ "\",\"reason\":\"" + reason + "\"}"));
		return ApiResponse.ok(response, traceId());
	}

	@PostMapping("/accounts/{id}/release")
	public ApiResponse<WorkerWarrantyAccountResponse> release(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID id) {
		WorkerWarrantyAccountResponse response =
			releases.release(principal.userId(), id);
		operationLogs.save(OperationLog.success(
			principal.userId(), "ADMIN_WORKER_WARRANTY_RELEASE",
			"WORKER_WARRANTY_ACCOUNT", id.toString(), traceId(),
			"{\"releasedTotal\":\"" + response.releasedTotal() + "\"}"));
		return ApiResponse.ok(response, traceId());
	}

	private WorkerWarrantyContributionStatus parseStatus(String value) {
		if (value == null || value.isBlank()) return null;
		try {
			return WorkerWarrantyContributionStatus.valueOf(
				value.trim().toUpperCase());
		} catch (IllegalArgumentException ex) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_WARRANTY_CONTRIBUTION_STATUS", "质保金补充状态无效");
		}
	}

	private static String json(String value) {
		return value == null ? ""
			: value.replace("\\", "\\\\").replace("\"", "\\\"");
	}

	private static String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}

	public record VerifyContributionRequest(
		@NotNull Boolean approved,
		@Size(max = 300) String reason
	) {}
}
