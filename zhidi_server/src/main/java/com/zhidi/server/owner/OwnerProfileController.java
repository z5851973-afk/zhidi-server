package com.zhidi.server.owner;

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
@RequestMapping("/api/v1/owners/me")
@Tag(name = "业主资料", description = "当前登录业主的个人资料接口")
public class OwnerProfileController {

	private final OwnerProfileService ownerProfileService;

	public OwnerProfileController(OwnerProfileService ownerProfileService) {
		this.ownerProfileService = ownerProfileService;
	}

	@GetMapping
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "获取当前业主资料")
	public ApiResponse<OwnerProfileResponse> get(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		OwnerProfileResponse response = ownerProfileService.get(principal.userId(), principal.phone());
		return ApiResponse.ok(response, traceId());
	}

	@PutMapping
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "更新当前业主资料")
	public ApiResponse<OwnerProfileResponse> update(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody OwnerProfileRequest request) {
		OwnerProfileResponse response = ownerProfileService.update(
			principal.userId(), principal.phone(), request);
		return ApiResponse.ok(response, traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
