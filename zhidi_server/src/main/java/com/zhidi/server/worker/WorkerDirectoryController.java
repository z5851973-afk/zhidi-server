package com.zhidi.server.worker;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/workers")
@Tag(name = "工匠目录", description = "业主浏览可展示工匠的列表和详情接口")
public class WorkerDirectoryController {

	private final WorkerProfileService workerProfileService;

	public WorkerDirectoryController(WorkerProfileService workerProfileService) {
		this.workerProfileService = workerProfileService;
	}

	@GetMapping
	@Operation(summary = "获取工匠列表")
	public ApiResponse<List<WorkerDirectoryResponse>> list() {
		return ApiResponse.ok(workerProfileService.listVisible(), traceId());
	}

	@GetMapping("/{userId}")
	@Operation(summary = "获取工匠详情")
	public ApiResponse<WorkerDirectoryResponse> detail(@PathVariable UUID userId) {
		return ApiResponse.ok(workerProfileService.getVisible(userId), traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
