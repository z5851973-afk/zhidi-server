package com.zhidi.server.owner;

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
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/owners/me/addresses")
public class OwnerAddressController {
	private final OwnerAddressService service;

	public OwnerAddressController(OwnerAddressService service) {
		this.service = service;
	}

	@GetMapping
	@PreAuthorize("hasRole('OWNER')")
	public ApiResponse<List<OwnerAddressResponse>> list(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(service.list(principal.userId()), traceId());
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	@PreAuthorize("hasRole('OWNER')")
	public ApiResponse<OwnerAddressResponse> create(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody OwnerAddressRequest request) {
		return ApiResponse.ok(service.create(principal.userId(), request), traceId());
	}

	@PutMapping("/{addressId}")
	@PreAuthorize("hasRole('OWNER')")
	public ApiResponse<OwnerAddressResponse> update(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID addressId,
			@Valid @RequestBody OwnerAddressRequest request) {
		return ApiResponse.ok(service.update(principal.userId(), addressId, request), traceId());
	}

	@PutMapping("/{addressId}/default")
	@PreAuthorize("hasRole('OWNER')")
	public ApiResponse<OwnerAddressResponse> setDefault(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID addressId) {
		return ApiResponse.ok(service.setDefault(principal.userId(), addressId), traceId());
	}

	@DeleteMapping("/{addressId}")
	@PreAuthorize("hasRole('OWNER')")
	public ApiResponse<Void> delete(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID addressId) {
		service.delete(principal.userId(), addressId);
		return ApiResponse.ok(null, traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
