package com.zhidi.server.inspection;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1")
public class InspectionController {

	private final InspectionService inspectionService;

	public InspectionController(InspectionService inspectionService) {
		this.inspectionService = inspectionService;
	}

	@PostMapping("/bookings/{bookingId}/inspection-nodes")
	@PreAuthorize("hasRole('WORKER')")
	public ApiResponse<List<InspectionNodeResponse>> createNodes(
			@PathVariable UUID bookingId,
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody List<CreateNodeRequest> requests) {
		return ApiResponse.ok(
			inspectionService.createNodes(principal.userId(), bookingId, requests),
			traceId());
	}

	@GetMapping("/bookings/{bookingId}/inspection-nodes")
	public ApiResponse<List<InspectionNodeResponse>> getNodes(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID bookingId) {
		return ApiResponse.ok(
			inspectionService.getNodes(principal.userId(), bookingId), traceId());
	}

	@PutMapping("/inspection-nodes/{nodeId}/request-inspection")
	@PreAuthorize("hasRole('WORKER')")
	public ApiResponse<InspectionNodeResponse> requestInspection(
			@PathVariable UUID nodeId,
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@RequestBody(required = false) InspectionSubmissionRequest request) {
		return ApiResponse.ok(
			inspectionService.requestInspection(principal.userId(), nodeId,
				request == null ? InspectionSubmissionRequest.empty() : request),
			traceId());
	}

	@PostMapping("/inspection-nodes/{nodeId}/inspect")
	@PreAuthorize("hasRole('OWNER')")
	public ApiResponse<InspectionRecordResponse> inspect(
			@PathVariable UUID nodeId,
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@Valid @RequestBody InspectRequest request) {
		return ApiResponse.ok(
			inspectionService.inspect(principal.userId(), nodeId, request),
			traceId());
	}

	@GetMapping("/inspection-nodes/{nodeId}/records")
	public ApiResponse<List<InspectionRecordResponse>> getRecords(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID nodeId) {
		return ApiResponse.ok(
			inspectionService.getRecords(principal.userId(), nodeId), traceId());
	}

	@GetMapping("/inspection-nodes/{nodeId}/timeline")
	public ApiResponse<List<InspectionTimelineResponse>> getTimeline(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID nodeId) {
		return ApiResponse.ok(
			inspectionService.getTimeline(principal.userId(), nodeId), traceId());
	}

	@PostMapping(value = "/inspection-nodes/{nodeId}/evidence",
		consumes = "multipart/form-data")
	@PreAuthorize("hasAnyRole('OWNER', 'WORKER')")
	public ApiResponse<InspectionEvidenceUploadResponse> uploadEvidence(
			@PathVariable UUID nodeId,
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@RequestParam("file") MultipartFile file) {
		return ApiResponse.ok(inspectionService.uploadEvidence(
			principal.userId(), nodeId, file), traceId());
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
