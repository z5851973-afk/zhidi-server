package com.zhidi.server.inspection;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record InspectionTimelineResponse(
		UUID id,
		UUID nodeId,
		String type,
		String actorRole,
		UUID actorUserId,
		int round,
		InspectionResult result,
		String note,
		List<String> photos,
		Instant createdAt
) {
	public static InspectionTimelineResponse from(InspectionSubmission submission) {
		return new InspectionTimelineResponse(
			submission.getId(), submission.getNodeId(), "WORKER_SUBMISSION",
			"WORKER", submission.getWorkerUserId(),
			submission.getSubmissionVersion(), null, submission.getNote(),
			submission.getPhotos(), submission.getCreatedAt());
	}

	public static InspectionTimelineResponse from(InspectionRecord record) {
		return new InspectionTimelineResponse(
			record.getId(), record.getNodeId(), "OWNER_DECISION", "OWNER",
			record.getInspectorUserId(), record.getInspectionVersion(),
			record.getResult(), record.getComment(), record.getPhotos(),
			record.getCreatedAt());
	}
}
