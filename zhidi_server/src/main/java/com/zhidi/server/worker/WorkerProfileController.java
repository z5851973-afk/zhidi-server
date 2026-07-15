package com.zhidi.server.worker;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.slf4j.MDC;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/workers/me")
@Tag(name = "工匠资料", description = "当前登录工匠的个人资料接口")
public class WorkerProfileController {

	private final WorkerProfileService workerProfileService;

	public WorkerProfileController(WorkerProfileService workerProfileService) {
		this.workerProfileService = workerProfileService;
	}

	@GetMapping
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "获取当前工匠资料")
	public ApiResponse<WorkerProfileResponse> get(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		WorkerProfileResponse response = workerProfileService.get(
			principal.userId(), principal.phone());
		return ApiResponse.ok(response, traceId());
	}

	@PutMapping
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "更新当前工匠资料")
	public ApiResponse<WorkerProfileResponse> update(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody WorkerProfileRequest request) {
		WorkerProfileResponse response = workerProfileService.update(
			principal.userId(), principal.phone(), request);
		return ApiResponse.ok(response, traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
