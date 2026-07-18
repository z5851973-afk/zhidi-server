package com.zhidi.server.inspection;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record InspectionRecordResponse(
		UUID id,
		UUID nodeId,
		UUID inspectorUserId,
		InspectionResult result,
		String comment,
		List<String> photos,
		int version,
		Instant createdAt
) {
	public static InspectionRecordResponse from(InspectionRecord record) {
		return new InspectionRecordResponse(
				record.getId(),
				record.getNodeId(),
				record.getInspectorUserId(),
				record.getResult(),
				record.getComment(),
				record.getPhotos(),
				record.getVersion(),
				record.getCreatedAt()
		);
	}
}
