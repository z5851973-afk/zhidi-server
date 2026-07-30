package com.zhidi.server.admin;

import com.zhidi.server.audit.OperationLog;
import java.time.Instant;
import java.util.UUID;

public record OperationLogResponse(
	UUID id,
	UUID actorUserId,
	String action,
	String targetType,
	String targetId,
	String result,
	String traceId,
	String detailJson,
	Instant createdAt
) {
	static OperationLogResponse from(OperationLog log) {
		return new OperationLogResponse(
			log.getId(),
			log.getActorUserId(),
			log.getAction(),
			log.getTargetType(),
			log.getTargetId(),
			log.getResult(),
			log.getTraceId(),
			log.getDetailJson(),
			log.getCreatedAt());
	}
}
