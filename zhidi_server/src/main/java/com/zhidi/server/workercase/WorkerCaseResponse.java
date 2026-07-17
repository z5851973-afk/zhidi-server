package com.zhidi.server.workercase;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record WorkerCaseResponse(
	UUID id,
	UUID workerUserId,
	String title,
	String description,
	String serviceCity,
	int completionYear,
	List<String> imageUrls,
	Instant createdAt,
	Instant updatedAt
) {
	static WorkerCaseResponse from(WorkerCase value) {
		return new WorkerCaseResponse(value.getId(), value.getWorkerUserId(),
			value.getTitle(), value.getDescription(), value.getServiceCity(),
			value.getCompletionYear(), value.getImageUrls(), value.getCreatedAt(),
			value.getUpdatedAt());
	}
}
