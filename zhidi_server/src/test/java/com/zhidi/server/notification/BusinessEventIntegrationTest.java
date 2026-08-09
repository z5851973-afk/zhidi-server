package com.zhidi.server.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.support.MySqlContainerSupport;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class BusinessEventIntegrationTest extends MySqlContainerSupport {

	private static final AtomicInteger PHONE_SEQUENCE = new AtomicInteger(1);
	private static final Instant OCCURRED_AT =
		Instant.parse("2026-08-09T08:00:00Z");

	@Autowired
	BusinessEventPublisher publisher;

	@Autowired
	BusinessEventService service;

	@Autowired
	BusinessEventRepository events;

	@Autowired
	BusinessEventStreamRepository streams;

	@Autowired
	UserRepository users;

	@Autowired
	PlatformTransactionManager transactionManager;

	@Autowired
	MockMvc mvc;

	@Autowired
	JwtTokenService tokens;

	private User recipient;
	private User otherUser;

	@BeforeEach
	void setUp() {
		events.deleteAll();
		streams.deleteAll();
		recipient = createUser(UserRole.OWNER);
		otherUser = createUser(UserRole.WORKER);
	}

	@Test
	void idempotentPublishDoesNotConsumeSequenceAndCursorPagesNeverSkipEvents() {
		BusinessEvent first = publisher.publish(draft(
			recipient.getId(), "daily-report:first", UUID.randomUUID()));
		BusinessEvent duplicate = publisher.publish(draft(
			recipient.getId(), "daily-report:first", UUID.randomUUID()));
		BusinessEvent second = publisher.publish(draft(
			recipient.getId(), "daily-report:second", UUID.randomUUID()));
		BusinessEvent third = publisher.publish(draft(
			recipient.getId(), "daily-report:third", UUID.randomUUID()));

		assertThat(duplicate.getEventId()).isEqualTo(first.getEventId());
		assertThat(events.count()).isEqualTo(3);
		assertThat(streams.findById(recipient.getId()).orElseThrow()
			.getLastSequence()).isEqualTo(3);

		BusinessEventPageResponse firstPage = service.list(
			recipient.getId(), 0, 2);
		BusinessEventPageResponse secondPage = service.list(
			recipient.getId(), firstPage.nextCursor(), 2);
		BusinessEventPageResponse emptyPage = service.list(
			recipient.getId(), secondPage.nextCursor(), 2);

		assertThat(firstPage.items())
			.extracting(BusinessEventResponse::sequenceNo)
			.containsExactly(1L, 2L);
		assertThat(firstPage.nextCursor()).isEqualTo(2);
		assertThat(secondPage.items())
			.extracting(BusinessEventResponse::sequenceNo)
			.containsExactly(3L);
		assertThat(secondPage.nextCursor()).isEqualTo(3);
		assertThat(emptyPage.items()).isEmpty();
		assertThat(emptyPage.nextCursor()).isEqualTo(3);
		assertThat(List.of(
			firstPage.items().get(0).eventId(),
			firstPage.items().get(1).eventId(),
			secondPage.items().get(0).eventId()))
			.containsExactly(first.getEventId(), second.getEventId(), third.getEventId());
	}

	@Test
	void onlyRecipientCanReadAndRepeatedReadKeepsTheFirstTimestamp() {
		BusinessEvent event = publisher.publish(draft(
			recipient.getId(), "inspection:record:1", UUID.randomUUID()));

		assertThat(service.list(otherUser.getId(), 0, 100).items()).isEmpty();
		assertThatThrownBy(() -> service.markRead(
			otherUser.getId(), event.getEventId()))
			.isInstanceOfSatisfying(BusinessException.class, error -> {
				assertThat(error.status()).isEqualTo(HttpStatus.NOT_FOUND);
				assertThat(error.code()).isEqualTo("NOTIFICATION_NOT_FOUND");
			});

		BusinessEventResponse firstRead = service.markRead(
			recipient.getId(), event.getEventId());
		BusinessEventResponse repeatedRead = service.markRead(
			recipient.getId(), event.getEventId());

		assertThat(firstRead.readAt()).isNotNull();
		assertThat(repeatedRead.readAt()).isEqualTo(firstRead.readAt());
	}

	@Test
	void sameRecipientTransactionsSerializeBeforeAllocatingTheNextCursor()
			throws Exception {
		TransactionTemplate transaction = new TransactionTemplate(transactionManager);
		CountDownLatch firstPublished = new CountDownLatch(1);
		CountDownLatch releaseFirst = new CountDownLatch(1);
		CountDownLatch secondReady = new CountDownLatch(1);
		ExecutorService executor = Executors.newFixedThreadPool(2);
		try {
			Future<UUID> first = executor.submit(() -> transaction.execute(status -> {
				BusinessEvent event = publisher.publish(draft(
					recipient.getId(), "same-recipient:first", UUID.randomUUID()));
				firstPublished.countDown();
				await(releaseFirst);
				return event.getEventId();
			}));
			assertThat(firstPublished.await(5, TimeUnit.SECONDS)).isTrue();

			Future<UUID> second = executor.submit(() -> transaction.execute(status -> {
				secondReady.countDown();
				return publisher.publish(draft(
					recipient.getId(), "same-recipient:second", UUID.randomUUID()))
					.getEventId();
			}));
			assertThat(secondReady.await(5, TimeUnit.SECONDS)).isTrue();
			assertThatThrownBy(() -> second.get(300, TimeUnit.MILLISECONDS))
				.isInstanceOf(TimeoutException.class);

			releaseFirst.countDown();
			UUID firstId = first.get(5, TimeUnit.SECONDS);
			UUID secondId = second.get(5, TimeUnit.SECONDS);
			assertThat(events.findByRecipientUserIdOrderBySequenceNoAsc(
				recipient.getId()))
				.extracting(BusinessEvent::getEventId, BusinessEvent::getSequenceNo)
				.containsExactly(
					org.assertj.core.groups.Tuple.tuple(firstId, 1L),
					org.assertj.core.groups.Tuple.tuple(secondId, 2L));
		} finally {
			releaseFirst.countDown();
			executor.shutdownNow();
		}
	}

	@Test
	void differentRecipientStreamsCanCommitWhileAnotherStreamIsLocked()
			throws Exception {
		TransactionTemplate transaction = new TransactionTemplate(transactionManager);
		CountDownLatch firstPublished = new CountDownLatch(1);
		CountDownLatch releaseFirst = new CountDownLatch(1);
		ExecutorService executor = Executors.newFixedThreadPool(2);
		try {
			Future<BusinessEvent> first = executor.submit(() ->
				transaction.execute(status -> {
					BusinessEvent event = publisher.publish(draft(
						recipient.getId(), "recipient-a", UUID.randomUUID()));
					firstPublished.countDown();
					await(releaseFirst);
					return event;
				}));
			assertThat(firstPublished.await(5, TimeUnit.SECONDS)).isTrue();

			Future<BusinessEvent> second = executor.submit(() ->
				transaction.execute(status -> publisher.publish(draft(
					otherUser.getId(), "recipient-b", UUID.randomUUID()))));

			BusinessEvent committedSecond = second.get(5, TimeUnit.SECONDS);
			assertThat(committedSecond.getSequenceNo()).isEqualTo(1);
			assertThat(first.isDone()).isFalse();
			releaseFirst.countDown();
			assertThat(first.get(5, TimeUnit.SECONDS).getSequenceNo()).isEqualTo(1);
		} finally {
			releaseFirst.countDown();
			executor.shutdownNow();
		}
	}

	@Test
	void notificationHttpApiStartsAtZeroAndHidesAnotherRecipientsEvent()
			throws Exception {
		BusinessEvent event = publisher.publish(draft(
			recipient.getId(), "http:event", UUID.randomUUID()));

		mvc.perform(get("/api/v1/notifications")
				.queryParam("after", "0")
				.queryParam("size", "100")
				.header("Authorization", bearer(recipient)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.items.length()").value(1))
			.andExpect(jsonPath("$.data.items[0].eventId")
				.value(event.getEventId().toString()))
			.andExpect(jsonPath("$.data.items[0].sequenceNo").value(1))
			.andExpect(jsonPath("$.data.nextCursor").value(1));

		mvc.perform(put("/api/v1/notifications/{eventId}/read", event.getEventId())
				.header("Authorization", bearer(otherUser)))
			.andExpect(status().isNotFound())
			.andExpect(jsonPath("$.code").value("NOTIFICATION_NOT_FOUND"));
	}

	private BusinessEventDraft draft(UUID recipientUserId, String idempotencyKey,
			UUID aggregateId) {
		return new BusinessEventDraft(
			recipientUserId,
			otherUser.getId(),
			BusinessEventType.DAILY_REPORT_SUBMITTED,
			"DAILY_REPORT",
			aggregateId,
			UUID.randomUUID(),
			UUID.randomUUID(),
			idempotencyKey,
			Map.of("reportDate", "2026-08-09", "revision", 1),
			OCCURRED_AT);
	}

	private User createUser(UserRole role) {
		User user = User.create("166000" + String.format(
			"%05d", PHONE_SEQUENCE.getAndIncrement()));
		user.grantRole(role);
		return users.saveAndFlush(user);
	}

	private String bearer(User user) {
		return "Bearer " + tokens.issue(
			user.getId(), user.getPhone(), Set.of(
				user == recipient ? UserRole.OWNER : UserRole.WORKER))
			.accessToken();
	}

	private static void await(CountDownLatch latch) {
		try {
			if (!latch.await(10, TimeUnit.SECONDS)) {
				throw new IllegalStateException("latch timed out");
			}
		} catch (InterruptedException exception) {
			Thread.currentThread().interrupt();
			throw new IllegalStateException("interrupted", exception);
		}
	}
}
