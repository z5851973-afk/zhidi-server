package com.zhidi.server.notification;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BusinessEventPublisher {

	private final JdbcTemplate jdbc;
	private final BusinessEventStreamRepository streams;
	private final BusinessEventRepository events;

	public BusinessEventPublisher(JdbcTemplate jdbc,
			BusinessEventStreamRepository streams,
			BusinessEventRepository events) {
		this.jdbc = jdbc;
		this.streams = streams;
		this.events = events;
	}

	@Transactional
	public BusinessEvent publish(BusinessEventDraft draft) {
		return publishLocked(List.of(Objects.requireNonNull(draft))).getFirst();
	}

	@Transactional
	public List<BusinessEvent> publish(List<BusinessEventDraft> drafts) {
		if (drafts == null || drafts.isEmpty()) {
			return List.of();
		}
		return publishLocked(List.copyOf(drafts));
	}

	private List<BusinessEvent> publishLocked(List<BusinessEventDraft> drafts) {
		List<UUID> recipients = drafts.stream()
			.map(BusinessEventDraft::recipientUserId)
			.collect(java.util.stream.Collectors.collectingAndThen(
				java.util.stream.Collectors.toCollection(LinkedHashSet::new),
				ArrayList::new));
		recipients.sort(Comparator.comparing(UUID::toString));

		Map<UUID, BusinessEventStream> lockedStreams = new HashMap<>();
		for (UUID recipient : recipients) {
			jdbc.update("""
				INSERT IGNORE INTO business_event_streams
					(recipient_user_id, last_sequence)
				VALUES (UUID_TO_BIN(?), 0)
				""", recipient.toString());
			BusinessEventStream stream = streams.findByIdForUpdate(recipient)
				.orElseThrow(() -> new IllegalStateException(
					"business event stream was not created"));
			lockedStreams.put(recipient, stream);
		}

		Map<EventKey, BusinessEvent> resolved = new HashMap<>();
		List<BusinessEvent> result = new ArrayList<>(drafts.size());
		for (BusinessEventDraft draft : drafts) {
			EventKey key = new EventKey(
				draft.recipientUserId(), draft.idempotencyKey());
			BusinessEvent event = resolved.get(key);
			if (event == null) {
				event = events.findByRecipientUserIdAndIdempotencyKey(
					draft.recipientUserId(), draft.idempotencyKey())
					.orElseGet(() -> events.save(BusinessEvent.create(
						lockedStreams.get(draft.recipientUserId())
							.nextSequence(), draft)));
				resolved.put(key, event);
			}
			result.add(event);
		}
		return List.copyOf(result);
	}

	private record EventKey(UUID recipientUserId, String idempotencyKey) {
	}
}
