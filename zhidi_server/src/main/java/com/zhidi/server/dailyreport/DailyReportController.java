package com.zhidi.server.dailyreport;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class DailyReportController {

	private final DailyReportService reportService;

	public DailyReportController(DailyReportService reportService) {
		this.reportService = reportService;
	}

	@PostMapping("/bookings/{bookingId}/daily-reports")
	@PreAuthorize("hasRole('WORKER')")
	@ResponseStatus(HttpStatus.CREATED)
	public ResponseEntity<ApiResponse<DailyReportResponse>> submit(
			@PathVariable UUID bookingId,
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody DailyReportRequest request) {
		return ResponseEntity.status(HttpStatus.CREATED)
			.body(ApiResponse.ok(
				reportService.submit(principal.userId(), bookingId, request),
				traceId()));
	}

	@GetMapping("/bookings/{bookingId}/daily-reports")
	public ApiResponse<List<DailyReportResponse>> getByBooking(
			@PathVariable UUID bookingId) {
		return ApiResponse.ok(reportService.findByBooking(bookingId), traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
