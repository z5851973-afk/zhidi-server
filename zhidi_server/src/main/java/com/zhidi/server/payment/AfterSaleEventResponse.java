package com.zhidi.server.payment;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record AfterSaleEventResponse(
	UUID id,
	UUID afterSaleId,
	UUID actorUserId,
	AfterSaleActorRole actorRole,
	AfterSaleEventType type,
	String content,
	List<String> evidenceUrls,
	String idempotencyKey,
	Instant createdAt
) {
	public static AfterSaleEventResponse from(AfterSaleEvent event) {
		return new AfterSaleEventResponse(event.getId(), event.getAfterSaleId(),
			event.getActorUserId(), event.getActorRole(), event.getType(),
			event.getContent(), event.getEvidenceUrls(), event.getIdempotencyKey(),
			event.getCreatedAt());
	}
}
