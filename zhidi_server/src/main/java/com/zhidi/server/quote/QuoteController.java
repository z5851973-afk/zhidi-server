package com.zhidi.server.quote;

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
@Tag(name = "报价", description = "工人提交报价和查询报价接口")
public class QuoteController {

	private final QuoteService quoteService;

	public QuoteController(QuoteService quoteService) {
		this.quoteService = quoteService;
	}

	@PostMapping("/api/v1/bookings/{bookingId}/quotes")
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "工人提交报价")
	public ApiResponse<QuoteResponse> submit(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID bookingId,
			@Valid @RequestBody QuoteRequest request) {
		return ApiResponse.ok(
			quoteService.submit(principal.userId(), bookingId, request),
			traceId());
	}

	@GetMapping("/api/v1/bookings/{bookingId}/quotes")
	@PreAuthorize("hasAnyRole('OWNER', 'WORKER')")
	@Operation(summary = "查看某预约的报价列表")
	public ApiResponse<List<QuoteResponse>> listForBooking(
			@PathVariable UUID bookingId) {
		return ApiResponse.ok(quoteService.listForBooking(bookingId),
			traceId());
	}

	@GetMapping("/api/v1/workers/me/quotes")
	@PreAuthorize("hasRole('WORKER')")
	@Operation(summary = "工人查看自己的报价列表")
	public ApiResponse<List<QuoteResponse>> listForWorker(
			@AuthenticationPrincipal CurrentUserPrincipal principal) {
		return ApiResponse.ok(quoteService.listForWorker(principal.userId()),
			traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
