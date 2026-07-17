package com.zhidi.server.servicerequest;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
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
@Tag(name = "装修需求", description = "业主创建装修需求和管理候选师傅")
public class ServiceRequestController {

	private final ServiceRequestService service;

	public ServiceRequestController(ServiceRequestService service) {
		this.service = service;
	}

	@PostMapping("/api/v1/owners/me/service-requests")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主创建装修需求")
	public ApiResponse<ServiceRequestResponse> create(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody ServiceRequestCreateRequest request) {
		return ApiResponse.ok(service.createRequest(principal.userId(), request), traceId());
	}

	@GetMapping("/api/v1/owners/me/service-requests")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主查看自己的装修需求")
	public ApiResponse<List<ServiceRequestResponse>> listForOwner(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(service.listOwnerRequests(principal.userId()), traceId());
	}

	@PostMapping("/api/v1/owners/me/service-requests/{requestId}/candidates")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "为装修需求添加候选师傅")
	public ApiResponse<ServiceRequestResponse> addCandidate(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID requestId,
			@Valid @RequestBody CandidateCreateRequest request) {
		return ApiResponse.ok(service.addCandidate(principal.userId(), requestId, request),
			traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
