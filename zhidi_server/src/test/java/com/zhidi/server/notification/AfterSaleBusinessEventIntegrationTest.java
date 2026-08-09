package com.zhidi.server.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.doThrow;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.payment.AfterSale;
import com.zhidi.server.payment.AfterSaleEvent;
import com.zhidi.server.payment.AfterSaleEventRepository;
import com.zhidi.server.payment.AfterSaleEventResponse;
import com.zhidi.server.payment.AfterSaleEventType;
import com.zhidi.server.payment.AfterSaleRepository;
import com.zhidi.server.payment.AfterSaleResponse;
import com.zhidi.server.payment.AfterSaleService;
import com.zhidi.server.payment.AfterSaleStatus;
import com.zhidi.server.payment.AfterSaleType;
import com.zhidi.server.payment.PaymentOrder;
import com.zhidi.server.payment.PaymentOrderRepository;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.util.ReflectionTestUtils;

@SpringBootTest
@ActiveProfiles("test")
class AfterSaleBusinessEventIntegrationTest extends MySqlContainerSupport {

	private static final AtomicInteger PHONE_SEQUENCE = new AtomicInteger(1);

	@Autowired
	AfterSaleService service;

	@Autowired
	AfterSaleRepository afterSales;

	@Autowired
	AfterSaleEventRepository afterSaleEvents;

	@Autowired
	BusinessEventRepository businessEvents;

	@Autowired
	BusinessEventStreamRepository businessEventStreams;

	@Autowired
	PaymentOrderRepository paymentOrders;

	@Autowired
	BookingRepository bookings;

	@Autowired
	ServiceRequestRepository serviceRequests;

	@Autowired
	UserRepository users;

	@MockitoSpyBean
	BusinessEventPublisher publisher;

	private User owner;
	private User worker;
	private User admin;
	private Booking booking;

	@BeforeEach
	void setUp() {
		businessEvents.deleteAll();
		businessEventStreams.deleteAll();
		afterSaleEvents.deleteAll();
		afterSales.deleteAll();
		paymentOrders.deleteAll();
		bookings.deleteAll();
		serviceRequests.deleteAll();
		users.deleteAll();

		owner = createUser(UserRole.OWNER);
		worker = createUser(UserRole.WORKER);
		admin = createUser(UserRole.ADMIN);
		booking = createCompletedPaidBooking();
	}

	@Test
	void eachCreatedTicketUsesItsOwnV28EventIdForTwoRecipientDelivery() {
		AfterSaleResponse first = createTicket("第一张工单");
		AfterSaleEvent firstCreated = event(first.id(), AfterSaleEventType.CREATED);

		AfterSale firstTicket = afterSales.findById(first.id()).orElseThrow();
		firstTicket.markPlatformProcessing();
		firstTicket.process("测试夹具结束第一张工单");
		firstTicket.close();
		afterSales.saveAndFlush(firstTicket);

		AfterSaleResponse second = createTicket("第二张工单");
		AfterSaleEvent secondCreated = event(second.id(), AfterSaleEventType.CREATED);

		assertThat(first.id()).isNotEqualTo(second.id());
		assertThat(firstCreated.getId()).isNotEqualTo(secondCreated.getId());
		assertThat(eventsFor(owner.getId(), BusinessEventType.AFTER_SALE_CREATED))
			.hasSize(2)
			.extracting(BusinessEvent::getAggregateId)
			.containsExactly(first.id(), second.id());
		assertThat(eventsFor(worker.getId(), BusinessEventType.AFTER_SALE_CREATED))
			.hasSize(2)
			.extracting(BusinessEvent::getAggregateId)
			.containsExactly(first.id(), second.id());
		assertDelivery(firstCreated, owner.getId(),
			BusinessEventType.AFTER_SALE_CREATED);
		assertDelivery(firstCreated, worker.getId(),
			BusinessEventType.AFTER_SALE_CREATED);
		assertDelivery(secondCreated, owner.getId(),
			BusinessEventType.AFTER_SALE_CREATED);
		assertDelivery(secondCreated, worker.getId(),
			BusinessEventType.AFTER_SALE_CREATED);
	}

	@Test
	void participantMessageIsDeliveredOnlyToTheOtherPartyAndReplayDoesNotDuplicateIt() {
		AfterSaleResponse ticket = createTicket("墙面开裂");

		AfterSaleEventResponse ownerMessage = service.appendParticipantEvent(
			owner.getId(), ticket.id(), "补充墙面照片", List.of(), "owner-draft-1");
		AfterSaleEventResponse replay = service.appendParticipantEvent(
			owner.getId(), ticket.id(), "网络重试不应新增", List.of(),
			"owner-draft-1");
		AfterSaleEventResponse workerMessage = service.appendParticipantEvent(
			worker.getId(), ticket.id(), "已安排返修", List.of(), "worker-draft-1");

		assertThat(replay.id()).isEqualTo(ownerMessage.id());
		assertThat(afterSaleEvents.findByAfterSaleIdOrderByCreatedAtAscIdAsc(
			ticket.id())).extracting(AfterSaleEvent::getType)
			.containsExactlyInAnyOrder(
				AfterSaleEventType.CREATED,
				AfterSaleEventType.PARTICIPANT_MESSAGE,
				AfterSaleEventType.PARTICIPANT_MESSAGE);

		List<BusinessEvent> ownerDeliveries = eventsFor(owner.getId(),
			BusinessEventType.AFTER_SALE_PARTICIPANT_MESSAGE);
		List<BusinessEvent> workerDeliveries = eventsFor(worker.getId(),
			BusinessEventType.AFTER_SALE_PARTICIPANT_MESSAGE);
		assertThat(ownerDeliveries).singleElement().satisfies(delivery -> {
			assertThat(delivery.getActorUserId()).isEqualTo(worker.getId());
			assertThat(delivery.getIdempotencyKey())
				.isEqualTo("after-sale-event:" + workerMessage.id());
		});
		assertThat(workerDeliveries).singleElement().satisfies(delivery -> {
			assertThat(delivery.getActorUserId()).isEqualTo(owner.getId());
			assertThat(delivery.getIdempotencyKey())
				.isEqualTo("after-sale-event:" + ownerMessage.id());
		});
		assertThat(businessEvents.findByRecipientUserIdOrderBySequenceNoAsc(
			owner.getId())).hasSize(2);
		assertThat(businessEvents.findByRecipientUserIdOrderBySequenceNoAsc(
			worker.getId())).hasSize(2);
	}

	@Test
	void platformLifecycleDeliversFourMappedV28EventsToBothParticipants() {
		AfterSaleResponse ticket = createTicket("需要平台协调");

		service.adminAccept(admin.getId(), ticket.id());
		service.appendAdminReply(admin.getId(), ticket.id(), "平台已联系双方",
			List.of());
		service.adminResolve(admin.getId(), ticket.id(), "安排返修", null);
		service.adminClose(admin.getId(), ticket.id(), "双方确认完成");

		assertThat(businessEvents.findByRecipientUserIdOrderBySequenceNoAsc(
			owner.getId())).extracting(BusinessEvent::getEventType)
			.containsExactly(
				BusinessEventType.AFTER_SALE_CREATED,
				BusinessEventType.AFTER_SALE_PLATFORM_ACCEPTED,
				BusinessEventType.AFTER_SALE_PLATFORM_REPLIED,
				BusinessEventType.AFTER_SALE_RESOLVED,
				BusinessEventType.AFTER_SALE_CLOSED);
		assertThat(businessEvents.findByRecipientUserIdOrderBySequenceNoAsc(
			worker.getId())).extracting(BusinessEvent::getEventType)
			.containsExactly(
				BusinessEventType.AFTER_SALE_CREATED,
				BusinessEventType.AFTER_SALE_PLATFORM_ACCEPTED,
				BusinessEventType.AFTER_SALE_PLATFORM_REPLIED,
				BusinessEventType.AFTER_SALE_RESOLVED,
				BusinessEventType.AFTER_SALE_CLOSED);

		assertMappedForBoth(ticket.id(), AfterSaleEventType.PLATFORM_ACCEPTED,
			BusinessEventType.AFTER_SALE_PLATFORM_ACCEPTED);
		assertMappedForBoth(ticket.id(), AfterSaleEventType.PLATFORM_REPLY,
			BusinessEventType.AFTER_SALE_PLATFORM_REPLIED);
		assertMappedForBoth(ticket.id(), AfterSaleEventType.RESOLVED,
			BusinessEventType.AFTER_SALE_RESOLVED);
		assertMappedForBoth(ticket.id(), AfterSaleEventType.CLOSED,
			BusinessEventType.AFTER_SALE_CLOSED);
	}

	@Test
	void deliveryFailureRollsBackCreatedTicketAndItsV28TimelineEvent() {
		doThrow(new IllegalStateException("business event delivery failed"))
			.when(publisher).publish(anyList());

		assertThatThrownBy(() -> createTicket("发布失败必须整体回滚"))
			.isInstanceOf(IllegalStateException.class)
			.hasMessage("business event delivery failed");

		assertThat(afterSales.findByBookingIdOrderByCreatedAtDesc(booking.getId()))
			.isEmpty();
		assertThat(afterSaleEvents.count()).isZero();
		assertThat(businessEvents.count()).isZero();
	}

	@Test
	void deliveryFailureRollsBackPlatformStatusAndItsV28TimelineEvent() {
		AfterSaleResponse ticket = createTicket("受理状态也必须原子提交");
		long businessEventCount = businessEvents.count();
		doThrow(new IllegalStateException("business event delivery failed"))
			.when(publisher).publish(anyList());

		assertThatThrownBy(() -> service.adminAccept(admin.getId(), ticket.id()))
			.isInstanceOf(IllegalStateException.class)
			.hasMessage("business event delivery failed");

		assertThat(afterSales.findById(ticket.id()).orElseThrow().getStatus())
			.isEqualTo(AfterSaleStatus.OPEN);
		assertThat(afterSaleEvents.findByAfterSaleIdOrderByCreatedAtAscIdAsc(
			ticket.id())).extracting(AfterSaleEvent::getType)
			.containsExactly(AfterSaleEventType.CREATED);
		assertThat(businessEvents.count()).isEqualTo(businessEventCount);
	}

	private void assertMappedForBoth(UUID afterSaleId,
			AfterSaleEventType afterSaleEventType,
			BusinessEventType businessEventType) {
		AfterSaleEvent timelineEvent = event(afterSaleId, afterSaleEventType);
		assertDelivery(timelineEvent, owner.getId(), businessEventType);
		assertDelivery(timelineEvent, worker.getId(), businessEventType);
	}

	private void assertDelivery(AfterSaleEvent timelineEvent, UUID recipientId,
			BusinessEventType eventType) {
		BusinessEvent delivery = businessEvents
			.findByRecipientUserIdAndIdempotencyKey(recipientId,
				"after-sale-event:" + timelineEvent.getId())
			.orElseThrow();
		AfterSale ticket = afterSales.findById(timelineEvent.getAfterSaleId())
			.orElseThrow();
		assertThat(delivery.getRecipientUserId()).isEqualTo(recipientId);
		assertThat(delivery.getActorUserId())
			.isEqualTo(timelineEvent.getActorUserId());
		assertThat(delivery.getEventType()).isEqualTo(eventType);
		assertThat(delivery.getAggregateType()).isEqualTo("AFTER_SALE");
		assertThat(delivery.getAggregateId()).isEqualTo(ticket.getId());
		assertThat(delivery.getBookingId()).isEqualTo(booking.getId());
		assertThat(delivery.getServiceRequestId())
			.isEqualTo(booking.getServiceRequestId());
		assertThat(delivery.getPayload()).containsExactly(
			org.assertj.core.api.Assertions.entry(
				"afterSaleEventType", timelineEvent.getType().name()));
		assertThat(delivery.getOccurredAt()).isEqualTo(timelineEvent.getCreatedAt());
	}

	private List<BusinessEvent> eventsFor(UUID recipientId,
			BusinessEventType eventType) {
		return businessEvents.findByRecipientUserIdOrderBySequenceNoAsc(recipientId)
			.stream()
			.filter(event -> event.getEventType() == eventType)
			.toList();
	}

	private AfterSaleEvent event(UUID afterSaleId, AfterSaleEventType type) {
		return afterSaleEvents.findByAfterSaleIdOrderByCreatedAtAscIdAsc(afterSaleId)
			.stream()
			.filter(event -> event.getType() == type)
			.findFirst()
			.orElseThrow();
	}

	private AfterSaleResponse createTicket(String reason) {
		return service.create(booking.getId(), owner.getId(),
			AfterSaleType.COMPLAINT, reason, List.of());
	}

	private Booking createCompletedPaidBooking() {
		ServiceRequest request = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "carpentry", "成都市", "武侯区一号", null));
		Booking savedBooking = Booking.createCandidate(request, owner.getId(),
			"张女士", owner.getPhone(), worker.getId(), "李师傅");
		ReflectionTestUtils.setField(savedBooking, "status", BookingStatus.COMPLETED);
		savedBooking = bookings.saveAndFlush(savedBooking);

		PaymentOrder payment = PaymentOrder.createOffline(savedBooking.getId(),
			owner.getId(), worker.getId(), null, new BigDecimal("1000.00"));
		payment.reportOfflinePayment("银行转账", "fixture-payment", null);
		payment.confirmOfflineReceipt();
		paymentOrders.saveAndFlush(payment);
		return savedBooking;
	}

	private User createUser(UserRole role) {
		User user = User.create("166" + String.format("%08d",
			PHONE_SEQUENCE.getAndIncrement()));
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
