package com.zhidi.server.dailyreport;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
public class DailyReportController {

	private final DailyReportService reportService;

	public DailyReportController(DailyReportService reportService) {
		this.reportService = reportService;
	}

	@PostMapping("/bookings/{bookingId}/reports")
	@PreAuthorize("hasRole('WORKER')")
	@ResponseStatus(HttpStatus.CREATED)
	public ResponseEntity<ApiResponse<DailyReportResponse>> submit(
			@PathVariable UUID bookingId,
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@RequestBody DailyReportRequest request) {
		return ResponseEntity.status(HttpStatus.CREATED)
			.body(ApiResponse.ok(reportService.submit(bookingId, principal.userId(), request), traceId()));
	}

	@GetMapping("/bookings/{bookingId}/reports")
	public ApiResponse<List<DailyReportResponse>> getByBooking(@PathVariable UUID bookingId) {
		return ApiResponse.ok(reportService.findByBooking(bookingId), traceId());
	}

	@GetMapping("/workers/me/reports")
	@PreAuthorize("hasRole('WORKER')")
	public ApiResponse<List<DailyReportResponse>> getMyReports(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(reportService.findByWorker(principal.userId()), traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
