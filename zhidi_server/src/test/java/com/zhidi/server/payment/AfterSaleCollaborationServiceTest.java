package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.infrastructure.storage.TencentCosProperties;
import com.zhidi.server.inspection.InspectionNode;
import com.zhidi.server.inspection.InspectionNodeRepository;
import com.zhidi.server.inspection.InspectionNodeStatus;
import com.zhidi.server.notification.BusinessEventPublisher;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

class AfterSaleCollaborationServiceTest {

	private final AfterSaleRepository afterSales = mock(AfterSaleRepository.class);
	private final AfterSaleEventRepository events =
		mock(AfterSaleEventRepository.class);
	private final BookingRepository bookings = mock(BookingRepository.class);
	private final WarrantyRetentionRepository warrantyRetentions =
		mock(WarrantyRetentionRepository.class);
	private final PaymentOrderRepository paymentOrders =
		mock(PaymentOrderRepository.class);
	private final WorkerWarrantyAccountService warrantyAccounts =
		mock(WorkerWarrantyAccountService.class);
	private final InspectionNodeRepository inspectionNodes =
		mock(InspectionNodeRepository.class);
	private final BusinessEventPublisher businessEvents =
		mock(BusinessEventPublisher.class);
	private AfterSaleService service;

	@BeforeEach
	void setUp() {
		service = new AfterSaleService(afterSales, events, bookings,
			warrantyRetentions, paymentOrders, warrantyAccounts, inspectionNodes,
			businessEvents,
			new TencentCosProperties(null, null, "zhidi-123", "ap-chengdu"));
		when(events.saveAndFlush(any())).thenAnswer(invocation -> {
			AfterSaleEvent event = invocation.getArgument(0);
			ReflectionTestUtils.setField(event, "id", UUID.randomUUID());
			ReflectionTestUtils.setField(event, "createdAt", Instant.now());
			return event;
		});
	}

	@Test
	void creationSnapshotsWorkerAndAppendsOwnerCreationEvent() {
		UUID bookingId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		Booking booking = completedBooking(ownerId, workerId);
		PaymentOrder payment = paidOrder(bookingId, ownerId, workerId);
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));
		when(paymentOrders.findByBookingId(bookingId))
			.thenReturn(Optional.of(payment));
		when(afterSales.saveAndFlush(any())).thenAnswer(invocation -> {
			AfterSale value = invocation.getArgument(0);
			ReflectionTestUtils.setField(value, "id", UUID.randomUUID());
			return value;
		});

		AfterSaleResponse response = service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "  木作开裂  ",
			List.of("/uploads/after-sales/photo.jpg"));

		assertThat(response.workerUserId()).isEqualTo(workerId);
		assertThat(response.reason()).isEqualTo("木作开裂");
		assertThat(response.dueAt()).isAfter(response.lastActivityAt());
		ArgumentCaptor<AfterSaleEvent> event =
			ArgumentCaptor.forClass(AfterSaleEvent.class);
		verify(events).saveAndFlush(event.capture());
		assertThat(event.getValue().getActorUserId()).isEqualTo(ownerId);
		assertThat(event.getValue().getActorRole()).isEqualTo(AfterSaleActorRole.OWNER);
		assertThat(event.getValue().getType()).isEqualTo(AfterSaleEventType.CREATED);
		assertThat(event.getValue().getEvidenceUrls())
			.containsExactly("/uploads/after-sales/photo.jpg");
	}

	@Test
	void ownerAndWorkerCanAppendButSameIdempotencyKeyIsNotDuplicated() {
		UUID afterSaleId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		AfterSale afterSale = afterSale(afterSaleId, ownerId, workerId);
		stubBusinessEventBooking(afterSale);
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		when(events.findByAfterSaleIdAndIdempotencyKey(afterSaleId, "owner-1"))
			.thenReturn(Optional.empty());

		service.appendParticipantEvent(ownerId, afterSaleId, "补充墙面照片",
			List.of("/uploads/after-sales/wall.jpg"), "owner-1");

		ArgumentCaptor<AfterSaleEvent> event =
			ArgumentCaptor.forClass(AfterSaleEvent.class);
		verify(events).saveAndFlush(event.capture());
		assertThat(event.getValue().getActorRole()).isEqualTo(AfterSaleActorRole.OWNER);

		AfterSaleEvent alreadySaved = AfterSaleEvent.create(afterSaleId, ownerId,
			AfterSaleActorRole.OWNER, AfterSaleEventType.PARTICIPANT_MESSAGE,
			"补充墙面照片", List.of(), "owner-1");
		when(events.findByAfterSaleIdAndIdempotencyKey(afterSaleId, "owner-1"))
			.thenReturn(Optional.of(alreadySaved));
		service.appendParticipantEvent(ownerId, afterSaleId, "不会重复",
			List.of(), "owner-1");

		verify(events, times(1)).saveAndFlush(any());

		when(events.findByAfterSaleIdAndIdempotencyKey(afterSaleId, "worker-1"))
			.thenReturn(Optional.empty());
		service.appendParticipantEvent(workerId, afterSaleId, "已安排返修",
			List.of(), "worker-1");
		verify(events, times(2)).saveAndFlush(event.capture());
		assertThat(event.getAllValues().getLast().getActorRole())
			.isEqualTo(AfterSaleActorRole.WORKER);
	}

	@Test
	void terminalTicketStillReturnsThePreviouslyCommittedIdempotentEvent() {
		UUID afterSaleId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		AfterSale afterSale = afterSale(
			afterSaleId, ownerId, UUID.randomUUID());
		afterSale.process("已处理");
		AfterSaleEvent committed = AfterSaleEvent.create(afterSaleId, ownerId,
			AfterSaleActorRole.OWNER, AfterSaleEventType.PARTICIPANT_MESSAGE,
			"网络超时前已提交", List.of(), "stable-draft-key");
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		when(events.findByAfterSaleIdAndIdempotencyKey(
			afterSaleId, "stable-draft-key")).thenReturn(Optional.of(committed));

		AfterSaleEventResponse replay = service.appendParticipantEvent(ownerId,
			afterSaleId, "网络超时后重试", List.of(), "stable-draft-key");

		assertThat(replay.content()).isEqualTo("网络超时前已提交");
		verify(events, never()).saveAndFlush(any());
	}

	@Test
	void nonParticipantCannotAppendOrEnumerateTicket() {
		UUID afterSaleId = UUID.randomUUID();
		AfterSale afterSale = afterSale(
			afterSaleId, UUID.randomUUID(), UUID.randomUUID());
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));

		assertThatThrownBy(() -> service.appendParticipantEvent(UUID.randomUUID(),
			afterSaleId, "探测", List.of(), "outsider-1"))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("AFTER_SALE_NOT_FOUND"));
		verify(events, never()).saveAndFlush(any());
	}

	@Test
	void adminLifecycleRequiresAcceptThenReplyResolveAndClose() {
		UUID afterSaleId = UUID.randomUUID();
		UUID adminId = UUID.randomUUID();
		AfterSale afterSale = afterSale(
			afterSaleId, UUID.randomUUID(), UUID.randomUUID());
		stubBusinessEventBooking(afterSale);
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		when(afterSales.saveAndFlush(afterSale)).thenReturn(afterSale);

		assertThatThrownBy(() -> service.adminResolve(adminId, afterSaleId,
			"返修", null))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("AFTER_SALE_NOT_ACCEPTED"));

		assertThat(service.adminAccept(adminId, afterSaleId).status())
			.isEqualTo(AfterSaleStatus.PLATFORM_PROCESSING);
		service.appendAdminReply(adminId, afterSaleId, "平台已联系双方", List.of());
		assertThat(service.adminResolve(adminId, afterSaleId, "安排返修", null).status())
			.isEqualTo(AfterSaleStatus.RESOLVED);
		assertThat(service.adminClose(adminId, afterSaleId, "双方确认完成").status())
			.isEqualTo(AfterSaleStatus.CLOSED);

		ArgumentCaptor<AfterSaleEvent> captured =
			ArgumentCaptor.forClass(AfterSaleEvent.class);
		verify(events, times(4)).saveAndFlush(captured.capture());
		assertThat(captured.getAllValues()).extracting(AfterSaleEvent::getType)
			.containsExactly(AfterSaleEventType.PLATFORM_ACCEPTED,
				AfterSaleEventType.PLATFORM_REPLY, AfterSaleEventType.RESOLVED,
				AfterSaleEventType.CLOSED);
		assertThat(afterSale.getAcceptedAt()).isNotNull();
		assertThat(afterSale.getResolvedAt()).isNotNull();
		assertThat(afterSale.getClosedAt()).isNotNull();
	}

	@Test
	void detailContainsOrderPaymentInspectionAndOnlyItsOwnTimeline() {
		UUID afterSaleId = UUID.randomUUID();
		UUID otherAfterSaleId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		AfterSale afterSale = afterSale(afterSaleId, bookingId, ownerId, workerId);
		Booking booking = completedBooking(ownerId, workerId);
		PaymentOrder payment = paidOrder(bookingId, ownerId, workerId);
		InspectionNode passed = InspectionNode.create(bookingId, "木工验收", null, 1);
		passed.requestInspection();
		passed.markPassed();
		InspectionNode unrelated = InspectionNode.create(
			bookingId, "油漆验收", null, 2);
		unrelated.requestInspection();
		unrelated.markFailed();
		AfterSaleEvent ownEvent = AfterSaleEvent.create(afterSaleId, ownerId,
			AfterSaleActorRole.OWNER, AfterSaleEventType.CREATED, "木作开裂",
			List.of(), "created-1");
		AfterSaleEvent otherEvent = AfterSaleEvent.create(otherAfterSaleId, ownerId,
			AfterSaleActorRole.OWNER, AfterSaleEventType.CREATED, "旧工单",
			List.of(), "created-2");
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));
		when(paymentOrders.findByBookingId(bookingId))
			.thenReturn(Optional.of(payment));
		when(inspectionNodes.findByBookingIdOrderBySortOrderAsc(bookingId))
			.thenReturn(List.of(passed, unrelated));
		when(events.findByAfterSaleIdOrderByCreatedAtAscIdAsc(afterSaleId))
			.thenReturn(List.of(ownEvent));

		AfterSaleDetailResponse detail = service.getAfterSale(ownerId, afterSaleId);

		assertThat(detail.context().trade()).isEqualTo("carpentry");
		assertThat(detail.context().bookingStatus()).isEqualTo("COMPLETED");
		assertThat(detail.context().workerName()).isEqualTo("李师傅");
		assertThat(detail.context().paymentStatus()).isEqualTo("PAID");
		assertThat(detail.context().inspection().status()).isEqualTo("PASSED");
		assertThat(detail.timeline()).extracting(AfterSaleEventResponse::content)
			.containsExactly("木作开裂")
			.doesNotContain(otherEvent.getContent());
		verify(events).findByAfterSaleIdOrderByCreatedAtAscIdAsc(afterSaleId);
		verify(events, never())
			.findByAfterSaleIdOrderByCreatedAtAscIdAsc(otherAfterSaleId);
	}

	@Test
	void ownerCanReadExactBookingContextBeforeCreatingTicket() {
		UUID bookingId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		Booking booking = completedBooking(ownerId, workerId);
		PaymentOrder payment = paidOrder(bookingId, ownerId, workerId);
		InspectionNode passed = InspectionNode.create(bookingId, "木工验收", null, 1);
		passed.requestInspection();
		passed.markPassed();
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));
		when(paymentOrders.findByBookingId(bookingId))
			.thenReturn(Optional.of(payment));
		when(inspectionNodes.findByBookingIdOrderBySortOrderAsc(bookingId))
			.thenReturn(List.of(passed));

		AfterSaleDetailResponse.OrderContext context =
			service.getBookingContext(ownerId, bookingId);

		assertThat(context.bookingId()).isEqualTo(bookingId);
		assertThat(context.bookingStatus()).isEqualTo("COMPLETED");
		assertThat(context.workerName()).isEqualTo("李师傅");
		assertThat(context.paymentStatus()).isEqualTo("PAID");
		assertThat(context.inspection().status()).isEqualTo("PASSED");
		assertThatThrownBy(() -> service.getBookingContext(
			UUID.randomUUID(), bookingId))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("AFTER_SALE_CONTEXT_NOT_FOUND"));
	}

	@Test
	void platformCosEvidenceIsAcceptedButExternalAndTraversalUrlsAreRejected() {
		UUID bookingId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		Booking booking = completedBooking(ownerId, workerId);
		PaymentOrder payment = paidOrder(bookingId, ownerId, workerId);
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));
		when(paymentOrders.findByBookingId(bookingId))
			.thenReturn(Optional.of(payment));
		when(afterSales.saveAndFlush(any())).thenAnswer(invocation -> {
			AfterSale value = invocation.getArgument(0);
			ReflectionTestUtils.setField(value, "id", UUID.randomUUID());
			return value;
		});

		AfterSaleResponse result = service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "木作开裂",
			List.of("https://zhidi-123.cos.ap-chengdu.myqcloud.com/after-sales/photo.jpg"));

		assertThat(result.evidenceUrls())
			.containsExactly(
				"https://zhidi-123.cos.ap-chengdu.myqcloud.com/after-sales/photo.jpg");

		assertThatThrownBy(() -> service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "外部跟踪图",
			List.of("https://attacker.example/after-sales/pixel.jpg")))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("INVALID_EVIDENCE_URL"));
		assertThatThrownBy(() -> service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "外部 COS 跟踪图",
			List.of("https://attacker-bucket.cos.ap-chengdu.myqcloud.com/"
				+ "after-sales/pixel.jpg")))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("INVALID_EVIDENCE_URL"));
		assertThatThrownBy(() -> service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "跨分类文件",
			List.of("/uploads/after-sales/../cases/photo.jpg")))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("INVALID_EVIDENCE_URL"));
		assertThatThrownBy(() -> service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "异常长地址",
			List.of("/uploads/after-sales/" + "a".repeat(2050) + ".jpg")))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("INVALID_EVIDENCE_URL"));
	}

	private Booking completedBooking(UUID ownerId, UUID workerId) {
		Booking booking = mock(Booking.class);
		when(booking.getOwnerUserId()).thenReturn(ownerId);
		when(booking.getWorkerUserId()).thenReturn(workerId);
		when(booking.getOwnerName()).thenReturn("张女士");
		when(booking.getWorkerName()).thenReturn("李师傅");
		when(booking.getTrade()).thenReturn("carpentry");
		when(booking.getServiceCity()).thenReturn("成都市");
		when(booking.getServiceAddress()).thenReturn("武侯区一号");
		when(booking.getServiceRequestId()).thenReturn(UUID.randomUUID());
		when(booking.getStatus()).thenReturn(BookingStatus.COMPLETED);
		return booking;
	}

	private PaymentOrder paidOrder(UUID bookingId, UUID ownerId, UUID workerId) {
		PaymentOrder payment = PaymentOrder.createOffline(bookingId, ownerId,
			workerId, UUID.randomUUID(), new BigDecimal("1000.00"));
		ReflectionTestUtils.setField(payment, "id", UUID.randomUUID());
		ReflectionTestUtils.setField(payment, "status", PaymentOrderStatus.PAID);
		return payment;
	}

	private AfterSale afterSale(UUID id, UUID ownerId, UUID workerId) {
		return afterSale(id, UUID.randomUUID(), ownerId, workerId);
	}

	private AfterSale afterSale(UUID id, UUID bookingId, UUID ownerId,
			UUID workerId) {
		AfterSale value = AfterSale.create(bookingId, ownerId, workerId,
			AfterSaleType.COMPLAINT, "木作开裂", null);
		ReflectionTestUtils.setField(value, "id", id);
		return value;
	}

	private void stubBusinessEventBooking(AfterSale afterSale) {
		Booking booking = mock(Booking.class);
		when(booking.getServiceRequestId()).thenReturn(UUID.randomUUID());
		when(bookings.findById(afterSale.getBookingId()))
			.thenReturn(Optional.of(booking));
	}
}
