package com.zhidi.server.booking;

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
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "预约", description = "业主预约工匠和工匠接单接口")
public class BookingController {

	private final BookingService bookingService;

	public BookingController(BookingService bookingService) {
		this.bookingService = bookingService;
	}

	@PostMapping("/api/v1/bookings")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主创建预约")
	public ApiResponse<BookingResponse> create(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody BookingRequest request) {
		return ApiResponse.ok(bookingService.create(principal.userId(), request), traceId());
	}

	@GetMapping("/api/v1/owners/me/bookings")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主查看自己的预约")
	public ApiResponse<List<BookingResponse>> listForOwner(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(bookingService.listForOwner(principal.userId()), traceId());
	}

	@GetMapping("/api/v1/workers/me/bookings")
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "工匠查看自己的待处理预约")
	public ApiResponse<List<BookingResponse>> listForWorker(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(bookingService.listForWorker(principal.userId()), traceId());
	}

	@PostMapping("/api/v1/workers/me/bookings/{id}/accept")
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "工匠接单")
	public ApiResponse<BookingResponse> accept(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID id) {
		return ApiResponse.ok(bookingService.accept(principal.userId(), id), traceId());
	}

	@PostMapping("/api/v1/workers/me/bookings/{id}/reject")
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "工匠拒单")
	public ApiResponse<BookingResponse> reject(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID id) {
		return ApiResponse.ok(bookingService.reject(principal.userId(), id), traceId());
	}

	@PostMapping("/api/v1/owners/me/bookings/{id}/cancel")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主取消预约")
	public ApiResponse<BookingResponse> ownerCancel(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID id,
			@Valid @RequestBody BookingCancellationRequest request) {
		return ApiResponse.ok(
			bookingService.ownerCancel(principal.userId(), id, request.reason()),
			traceId());
	}

	@PostMapping("/api/v1/workers/me/bookings/{id}/cancel")
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "工人取消预约")
	public ApiResponse<BookingResponse> workerCancel(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID id,
			@Valid @RequestBody BookingCancellationRequest request) {
		return ApiResponse.ok(
			bookingService.workerCancel(principal.userId(), id, request.reason()),
			traceId());
	}

	// Temporary legacy route — remove after Flutter client is upgraded
	@PostMapping("/api/v1/bookings/{id}/cancel")
	@PreAuthorize("hasRole('OWNER')")
	@Operation(summary = "业主取消预约（旧路径）")
	public ApiResponse<BookingResponse> cancelLegacy(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID id,
			@Valid @RequestBody BookingCancellationRequest request) {
		return ApiResponse.ok(
			bookingService.ownerCancel(principal.userId(), id, request.reason()),
			traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
