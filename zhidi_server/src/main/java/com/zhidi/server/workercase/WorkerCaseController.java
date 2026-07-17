package com.zhidi.server.workercase;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class WorkerCaseController {

	private final WorkerCaseService service;

	public WorkerCaseController(WorkerCaseService service) {
		this.service = service;
	}

	@GetMapping("/api/v1/workers/me/cases")
	@PreAuthorize("hasRole('WORKER')")
	public ApiResponse<List<WorkerCaseResponse>> listMine(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(service.listMine(principal.userId()), traceId());
	}

	@PostMapping("/api/v1/workers/me/cases")
	@PreAuthorize("hasRole('WORKER')")
	@ResponseStatus(HttpStatus.CREATED)
	public ApiResponse<WorkerCaseResponse> create(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody WorkerCaseRequest request) {
		return ApiResponse.ok(service.create(principal.userId(), request), traceId());
	}

	@PutMapping("/api/v1/workers/me/cases/{caseId}")
	@PreAuthorize("hasRole('WORKER')")
	public ApiResponse<WorkerCaseResponse> update(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID caseId,
			@Valid @RequestBody WorkerCaseRequest request) {
		return ApiResponse.ok(service.update(principal.userId(), caseId, request), traceId());
	}

	@DeleteMapping("/api/v1/workers/me/cases/{caseId}")
	@PreAuthorize("hasRole('WORKER')")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void delete(@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID caseId) {
		service.delete(principal.userId(), caseId);
	}

	@GetMapping("/api/v1/workers/{workerUserId}/cases")
	public ApiResponse<List<WorkerCaseResponse>> listPublic(
			@PathVariable UUID workerUserId) {
		return ApiResponse.ok(service.listPublic(workerUserId), traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
