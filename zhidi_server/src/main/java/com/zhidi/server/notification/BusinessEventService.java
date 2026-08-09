package com.zhidi.server.notification;

import com.zhidi.server.common.error.BusinessException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BusinessEventService {

	private final BusinessEventRepository events;

	public BusinessEventService(BusinessEventRepository events) {
		this.events = events;
	}

	@Transactional(readOnly = true)
	public BusinessEventPageResponse list(UUID recipientUserId, long after,
			int size) {
		if (after < 0) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_NOTIFICATION_CURSOR", "after must be non-negative");
		}
		if (size < 1 || size > 100) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_NOTIFICATION_PAGE_SIZE", "size must be between 1 and 100");
		}
		List<BusinessEventResponse> items = events
			.findByRecipientUserIdAndSequenceNoGreaterThanOrderBySequenceNoAsc(
				recipientUserId, after, PageRequest.of(0, size))
			.stream()
			.map(BusinessEventResponse::from)
			.toList();
		long nextCursor = items.isEmpty()
			? after : items.getLast().sequenceNo();
		return new BusinessEventPageResponse(items, nextCursor);
	}

	@Transactional
	public BusinessEventResponse markRead(UUID recipientUserId, UUID eventId) {
		BusinessEvent event = events.findByEventIdAndRecipientUserId(
			eventId, recipientUserId).orElseThrow(() -> new BusinessException(
				HttpStatus.NOT_FOUND,
				"NOTIFICATION_NOT_FOUND",
				"notification not found"));
		event.markRead(Instant.now());
		return BusinessEventResponse.from(event);
	}
}
