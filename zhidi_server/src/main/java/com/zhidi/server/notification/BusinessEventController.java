package com.zhidi.server.notification;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/notifications")
public class BusinessEventController {

	private final BusinessEventService events;

	public BusinessEventController(BusinessEventService events) {
		this.events = events;
	}

	@GetMapping
	public ApiResponse<BusinessEventPageResponse> list(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@RequestParam(defaultValue = "0") long after,
			@RequestParam(defaultValue = "100") int size) {
		return ApiResponse.ok(events.list(principal.userId(), after, size), traceId());
	}

	@PutMapping("/{eventId}/read")
	public ApiResponse<BusinessEventResponse> markRead(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID eventId) {
		return ApiResponse.ok(events.markRead(principal.userId(), eventId), traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
