package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.inspection.InspectionNode;
import com.zhidi.server.inspection.InspectionNodeRepository;
import com.zhidi.server.quote.Quote;
import com.zhidi.server.quote.QuoteItem;
import com.zhidi.server.quote.QuoteRepository;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

class PaymentOrderServiceOfflineTest {

	private final PaymentOrderRepository paymentOrders = mock(PaymentOrderRepository.class);
	private final BookingRepository bookings = mock(BookingRepository.class);
	private final QuoteRepository quotes = mock(QuoteRepository.class);
	private final InspectionNodeRepository inspectionNodes = mock(InspectionNodeRepository.class);
	private final SettlementRepository settlements = mock(SettlementRepository.class);
	private PaymentOrderService service;

	@BeforeEach
	void setUp() {
		service = new PaymentOrderService(
			paymentOrders, bookings, quotes, inspectionNodes, settlements);
	}

	@Test
	void paymentOrderRequiresAtLeastOnePassedInspectionNode() {
		UUID ownerId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		Booking booking = mock(Booking.class);
		when(booking.getOwnerUserId()).thenReturn(ownerId);
		when(booking.getStatus()).thenReturn(BookingStatus.HIRED);
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));
		when(inspectionNodes.findByBookingIdOrderBySortOrderAsc(bookingId))
			.thenReturn(List.of());

		assertThatThrownBy(() -> service.createOrder(ownerId, bookingId))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("INSPECTION_REQUIRED"));
		verify(quotes, never()).findByBookingIdOrderByCreatedAtDesc(any());
	}

	@Test
	void paymentOrderOnlyRequiresTheBookingTradeInspectionToPass() {
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		UUID quoteId = UUID.randomUUID();
		Booking booking = mock(Booking.class);
		when(booking.getId()).thenReturn(bookingId);
		when(booking.getOwnerUserId()).thenReturn(ownerId);
		when(booking.getWorkerUserId()).thenReturn(workerId);
		when(booking.getStatus()).thenReturn(BookingStatus.HIRED);
		when(booking.getTrade()).thenReturn("masonry");
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));

		InspectionNode masonry = InspectionNode.create(
			bookingId, "泥瓦验收", "贴砖、砌墙、地面找平验收", 1);
		masonry.requestInspection();
		masonry.markPassed();
		InspectionNode carpentry = InspectionNode.create(
			bookingId, "木工验收", "历史残留节点", 2);
		InspectionNode painting = InspectionNode.create(
			bookingId, "油漆验收", "历史残留节点", 3);
		when(inspectionNodes.findByBookingIdOrderBySortOrderAsc(bookingId))
			.thenReturn(List.of(masonry, carpentry, painting));

		Quote quote = Quote.create(bookingId, workerId, List.of(new QuoteItem(
			"泥瓦施工", new BigDecimal("1"), "项", new BigDecimal("160.00"),
			null, new BigDecimal("160.00"), null, null, null, null)));
		ReflectionTestUtils.setField(quote, "id", quoteId);
		quote.accept();
		when(quotes.findByBookingIdOrderByCreatedAtDesc(bookingId))
			.thenReturn(List.of(quote));
		when(paymentOrders.findByBookingId(bookingId)).thenReturn(Optional.empty());
		when(paymentOrders.saveAndFlush(any(PaymentOrder.class)))
			.thenAnswer(invocation -> invocation.getArgument(0));

		PaymentOrderResponse response = service.createOrder(ownerId, bookingId);

		assertThat(response.amount()).isEqualByComparingTo("160.00");
	}

	@Test
	void workerConfirmationCreatesAnAlreadyReceivedSettlement() {
		UUID orderId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		PaymentOrder order = PaymentOrder.createOffline(
			UUID.randomUUID(), ownerId, workerId, UUID.randomUUID(),
			new BigDecimal("360.00"));
		ReflectionTestUtils.setField(order, "id", orderId);
		order.reportOfflinePayment("微信转账", "wx-123", null);
		when(paymentOrders.findById(orderId)).thenReturn(Optional.of(order));
		when(paymentOrders.saveAndFlush(order)).thenReturn(order);
		when(settlements.findByPaymentOrderId(orderId)).thenReturn(Optional.empty());
		when(settlements.saveAndFlush(any(Settlement.class)))
			.thenAnswer(invocation -> invocation.getArgument(0));

		PaymentOrderResponse response = service.confirmOfflineReceipt(workerId, orderId);

		assertThat(response.status()).isEqualTo(PaymentOrderStatus.PAID);
		ArgumentCaptor<Settlement> captor = ArgumentCaptor.forClass(Settlement.class);
		verify(settlements).saveAndFlush(captor.capture());
		assertThat(captor.getValue().getStatus()).isEqualTo(SettlementStatus.SETTLED);
		assertThat(captor.getValue().getAmount()).isEqualByComparingTo("360.00");
	}

	@Test
	void ownerCannotConfirmWorkersReceipt() {
		UUID orderId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		PaymentOrder order = PaymentOrder.createOffline(
			UUID.randomUUID(), ownerId, UUID.randomUUID(), UUID.randomUUID(),
			new BigDecimal("80.00"));
		when(paymentOrders.findById(orderId)).thenReturn(Optional.of(order));

		assertThatThrownBy(() -> service.confirmOfflineReceipt(ownerId, orderId))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("NOT_WORKER"));
	}
}
