package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.infrastructure.storage.TencentCosProperties;
import com.zhidi.server.inspection.InspectionNodeRepository;
import com.zhidi.server.notification.BusinessEventPublisher;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

class AfterSaleServiceTest {

	private final AfterSaleRepository afterSales = mock(AfterSaleRepository.class);
	private final AfterSaleEventRepository events = mock(AfterSaleEventRepository.class);
	private final BookingRepository bookings = mock(BookingRepository.class);
	private final WarrantyRetentionRepository warrantyRetentions =
		mock(WarrantyRetentionRepository.class);
	private final PaymentOrderRepository paymentOrders =
		mock(PaymentOrderRepository.class);
	private final WorkerWarrantyAccountService warrantyAccounts =
		mock(WorkerWarrantyAccountService.class);
	private final BusinessEventPublisher businessEvents =
		mock(BusinessEventPublisher.class);
	private AfterSaleService service;

	@BeforeEach
	void setUp() {
		service = new AfterSaleService(afterSales, events, bookings,
			warrantyRetentions, paymentOrders, warrantyAccounts,
			mock(InspectionNodeRepository.class),
			businessEvents,
			new TencentCosProperties(null, null, "zhidi-123", "ap-chengdu"));
		when(events.saveAndFlush(org.mockito.ArgumentMatchers.any()))
			.thenAnswer(invocation -> {
				AfterSaleEvent event = invocation.getArgument(0);
				ReflectionTestUtils.setField(event, "id", UUID.randomUUID());
				ReflectionTestUtils.setField(event, "createdAt", Instant.now());
				return event;
			});
	}

	@Test
	void pendingBookingCannotCreateAfterSale() {
		UUID bookingId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		Booking booking = mock(Booking.class);
		when(booking.getOwnerUserId()).thenReturn(ownerId);
		when(booking.getWorkerUserId()).thenReturn(UUID.randomUUID());
		when(booking.getStatus()).thenReturn(BookingStatus.PENDING);
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));

		assertThatThrownBy(() -> service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "需要处理", List.of()))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("AFTER_SALE_NOT_AVAILABLE"));
		verify(paymentOrders, never()).findByBookingId(bookingId);
		verify(afterSales, never()).saveAndFlush(org.mockito.ArgumentMatchers.any());
	}

	@Test
	void completedBookingWithoutConfirmedPaymentCannotCreateAfterSale() {
		UUID bookingId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		Booking booking = mock(Booking.class);
		when(booking.getOwnerUserId()).thenReturn(ownerId);
		when(booking.getWorkerUserId()).thenReturn(UUID.randomUUID());
		when(booking.getServiceRequestId()).thenReturn(UUID.randomUUID());
		when(booking.getStatus()).thenReturn(BookingStatus.COMPLETED);
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));
		when(paymentOrders.findByBookingId(bookingId)).thenReturn(Optional.empty());

		assertThatThrownBy(() -> service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "需要处理", List.of()))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("AFTER_SALE_PAYMENT_REQUIRED"));
		verify(afterSales, never()).saveAndFlush(org.mockito.ArgumentMatchers.any());
	}

	@Test
	void completedPaidBookingCanCreateAfterSale() {
		UUID bookingId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		Booking booking = mock(Booking.class);
		PaymentOrder paymentOrder = mock(PaymentOrder.class);
		when(booking.getOwnerUserId()).thenReturn(ownerId);
		when(booking.getWorkerUserId()).thenReturn(UUID.randomUUID());
		when(booking.getServiceRequestId()).thenReturn(UUID.randomUUID());
		when(booking.getStatus()).thenReturn(BookingStatus.COMPLETED);
		when(paymentOrder.getStatus()).thenReturn(PaymentOrderStatus.PAID);
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));
		when(paymentOrders.findByBookingId(bookingId))
			.thenReturn(Optional.of(paymentOrder));
		when(afterSales.saveAndFlush(org.mockito.ArgumentMatchers.any()))
			.thenAnswer(invocation -> {
				AfterSale value = invocation.getArgument(0);
				ReflectionTestUtils.setField(value, "id", UUID.randomUUID());
				return value;
			});

		AfterSaleResponse response = service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "  需要处理  ", List.of());

		assertThat(response.bookingId()).isEqualTo(bookingId);
		assertThat(response.reason()).isEqualTo("需要处理");
		assertThat(response.status()).isEqualTo(AfterSaleStatus.OPEN);
	}

	@Test
	void bookingCannotOpenASecondActiveAfterSale() {
		UUID bookingId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		Booking booking = mock(Booking.class);
		PaymentOrder paymentOrder = mock(PaymentOrder.class);
		when(booking.getOwnerUserId()).thenReturn(ownerId);
		when(booking.getWorkerUserId()).thenReturn(UUID.randomUUID());
		when(booking.getStatus()).thenReturn(BookingStatus.COMPLETED);
		when(paymentOrder.getStatus()).thenReturn(PaymentOrderStatus.PAID);
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));
		when(paymentOrders.findByBookingId(bookingId))
			.thenReturn(Optional.of(paymentOrder));
		when(afterSales.existsByBookingIdAndStatusIn(
			org.mockito.ArgumentMatchers.eq(bookingId),
			org.mockito.ArgumentMatchers.anyCollection())).thenReturn(true);

		assertThatThrownBy(() -> service.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "需要处理", List.of()))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("AFTER_SALE_ALREADY_OPEN"));
		verify(afterSales, never()).saveAndFlush(org.mockito.ArgumentMatchers.any());
	}

	@Test
	void unrelatedUserGetsNotFoundWhenBookingHasNoWorker() {
		UUID afterSaleId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		AfterSale afterSale = AfterSale.create(bookingId, ownerId,
			AfterSaleType.COMPLAINT, "需要处理", null);
		Booking booking = mock(Booking.class);
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));
		when(booking.getOwnerUserId()).thenReturn(ownerId);
		when(booking.getWorkerUserId()).thenReturn(null);

		assertThatThrownBy(() -> service.getAfterSale(UUID.randomUUID(), afterSaleId))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("AFTER_SALE_NOT_FOUND"));
	}

	@Test
	void workerCanDiscoverAfterSalesForParticipatingBookings() {
		UUID workerId = UUID.randomUUID();
		AfterSale afterSale = AfterSale.create(UUID.randomUUID(), UUID.randomUUID(),
			AfterSaleType.COMPLAINT, "需要处理", null);
		when(afterSales.findForParticipant(workerId)).thenReturn(List.of(afterSale));

		List<AfterSaleResponse> response = service.listForUser(workerId);

		assertThat(response).hasSize(1);
		verify(afterSales).findForParticipant(workerId);
	}

	@Test
	void openAfterSaleCannotBeResolvedBeforePlatformAcceptsIt() {
		UUID afterSaleId = UUID.randomUUID();
		AfterSale afterSale = AfterSale.create(
			UUID.randomUUID(), UUID.randomUUID(), AfterSaleType.COMPLAINT,
			"木作开裂", null);
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		when(afterSales.saveAndFlush(afterSale)).thenReturn(afterSale);

		assertThatThrownBy(() -> service.process(afterSaleId, "平台判定返修"))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("AFTER_SALE_NOT_ACCEPTED"));
	}

	@Test
	void processingAfterSaleCanDeductWarrantyRetentionForTheBooking() {
		UUID afterSaleId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		AfterSale afterSale = AfterSale.create(
			bookingId, UUID.randomUUID(), AfterSaleType.COMPLAINT,
			"水管返潮", null);
		afterSale.markPlatformProcessing();
		ReflectionTestUtils.setField(afterSale, "id", afterSaleId);
		stubBusinessEventBooking(afterSale);
		WarrantyRetention retention = WarrantyRetention.create(
			UUID.randomUUID(), UUID.randomUUID(), bookingId, UUID.randomUUID(),
			new BigDecimal("100.00"));
		ReflectionTestUtils.setField(retention, "id", UUID.randomUUID());
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		PaymentOrder legacyOrder = PaymentOrder.createOffline(
			bookingId, UUID.randomUUID(), retention.getWorkerUserId(), UUID.randomUUID(),
			new BigDecimal("100.00"));
		when(paymentOrders.findByBookingId(bookingId))
			.thenReturn(Optional.of(legacyOrder));
		when(warrantyRetentions.findFirstByBookingIdOrderByCreatedAtDesc(bookingId))
			.thenReturn(Optional.of(retention));
		when(warrantyRetentions.saveAndFlush(retention)).thenReturn(retention);
		when(afterSales.saveAndFlush(afterSale)).thenReturn(afterSale);

		AfterSaleResponse response = service.process(
			afterSaleId, "平台判定返修，扣减质保金 ¥30",
			new BigDecimal("30.00"));

		assertThat(response.status()).isEqualTo(AfterSaleStatus.RESOLVED);
		assertThat(response.warrantyRetentionId()).isEqualTo(retention.getId());
		assertThat(response.warrantyDeductionAmount())
			.isEqualByComparingTo("30.00");
		assertThat(retention.getDeductedAmount()).isEqualByComparingTo("30.00");
		assertThat(retention.remainingAmount()).isEqualByComparingTo("70.00");
	}

	@Test
	void processingAfterSaleWithDeductionRequiresAWarrantyRetention() {
		UUID afterSaleId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		AfterSale afterSale = AfterSale.create(
			bookingId, UUID.randomUUID(), AfterSaleType.COMPLAINT,
			"水管返潮", null);
		afterSale.markPlatformProcessing();
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		PaymentOrder legacyOrder = PaymentOrder.createOffline(
			bookingId, UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			new BigDecimal("100.00"));
		when(paymentOrders.findByBookingId(bookingId))
			.thenReturn(Optional.of(legacyOrder));
		when(warrantyRetentions.findFirstByBookingIdOrderByCreatedAtDesc(bookingId))
			.thenReturn(Optional.empty());

		assertThatThrownBy(() -> service.process(
			afterSaleId, "平台判定扣减", new BigDecimal("30.00")))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("WARRANTY_RETENTION_NOT_FOUND"));
	}

	@Test
	void splitFundingModelDeductsWorkerWarrantyAccountInsteadOfLegacyRetention() {
		UUID afterSaleId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		AfterSale afterSale = AfterSale.create(
			bookingId, UUID.randomUUID(), AfterSaleType.COMPLAINT,
			"木作开裂", null);
		afterSale.markPlatformProcessing();
		ReflectionTestUtils.setField(afterSale, "id", afterSaleId);
		stubBusinessEventBooking(afterSale);
		PaymentOrder splitOrder = PaymentOrder.createSplitOffline(
			bookingId, UUID.randomUUID(), workerId, UUID.randomUUID(),
			new BigDecimal("5000.00"));
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		when(paymentOrders.findByBookingId(bookingId))
			.thenReturn(Optional.of(splitOrder));
		when(afterSales.saveAndFlush(afterSale)).thenReturn(afterSale);

		AfterSaleResponse response = service.process(
			afterSaleId, "平台判定扣减质保金", new BigDecimal("200.00"));

		verify(warrantyAccounts).deductForAfterSale(
			workerId, afterSaleId, new BigDecimal("200.00"), "平台判定扣减质保金");
		verify(warrantyRetentions,
			org.mockito.Mockito.never()).saveAndFlush(org.mockito.ArgumentMatchers.any());
		assertThat(response.warrantyRetentionId()).isNull();
		assertThat(response.warrantyDeductionAmount())
			.isEqualByComparingTo("200.00");
	}

	private void stubBusinessEventBooking(AfterSale afterSale) {
		Booking booking = mock(Booking.class);
		when(booking.getServiceRequestId()).thenReturn(UUID.randomUUID());
		when(bookings.findById(afterSale.getBookingId()))
			.thenReturn(Optional.of(booking));
	}
}
