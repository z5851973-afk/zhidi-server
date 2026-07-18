package com.zhidi.server.inspection;

import java.time.Instant;
import java.util.UUID;

public record InspectionNodeResponse(
		UUID id,
		UUID bookingId,
		String name,
		String description,
		InspectionNodeStatus status,
		int sortOrder,
		Instant createdAt,
		Instant updatedAt
) {
	public static InspectionNodeResponse from(InspectionNode node) {
		return new InspectionNodeResponse(
				node.getId(),
				node.getBookingId(),
				node.getName(),
				node.getDescription(),
				node.getStatus(),
				node.getSortOrder(),
				node.getCreatedAt(),
				node.getUpdatedAt()
		);
	}
}
