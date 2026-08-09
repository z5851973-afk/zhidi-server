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
	private final WarrantyRetentionRepository warrantyRetentions = mock(WarrantyRetentionRepository.class);
	private final WorkerWarrantyAccountService workerWarrantyAccounts =
		mock(WorkerWarrantyAccountService.class);
	private final PaymentReferenceClaimRepository paymentReferenceClaims =
		mock(PaymentReferenceClaimRepository.class);
	private PaymentOrderService service;

	@BeforeEach
	void setUp() {
		service = new PaymentOrderService(
			paymentOrders, bookings, quotes, inspectionNodes, settlements,
			warrantyRetentions, workerWarrantyAccounts, paymentReferenceClaims);
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

		assertThat(response.amount()).isEqualByComparingTo("176.00");
		assertThat(response.platformFee()).isEqualByComparingTo("16.00");
		assertThat(response.workerSettlement()).isEqualByComparingTo("160.00");
		assertThat(response.warrantyRetention()).isEqualByComparingTo("0.00");
		assertThat(response.fundingModel())
			.isEqualTo(PaymentFundingModel.OFFLINE_SPLIT_V2);
	}

	@Test
	void completedBookingCanStillCreateItsPaymentOrder() {
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		UUID quoteId = UUID.randomUUID();
		Booking booking = mock(Booking.class);
		when(booking.getId()).thenReturn(bookingId);
		when(booking.getOwnerUserId()).thenReturn(ownerId);
		when(booking.getWorkerUserId()).thenReturn(workerId);
		when(booking.getStatus()).thenReturn(BookingStatus.valueOf("COMPLETED"));
		when(booking.getTrade()).thenReturn("carpentry");
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));

		InspectionNode carpentry = InspectionNode.create(
			bookingId, "木工验收", "柜体结构验收", 1);
		carpentry.requestInspection();
		carpentry.markPassed();
		when(inspectionNodes.findByBookingIdOrderBySortOrderAsc(bookingId))
			.thenReturn(List.of(carpentry));

		Quote quote = Quote.create(bookingId, workerId, List.of(new QuoteItem(
			"柜体安装", new BigDecimal("1"), "项", new BigDecimal("500.00"),
			null, new BigDecimal("500.00"), null, null, null, null)));
		ReflectionTestUtils.setField(quote, "id", quoteId);
		quote.accept();
		when(quotes.findByBookingIdOrderByCreatedAtDesc(bookingId))
			.thenReturn(List.of(quote));
		when(paymentOrders.findByBookingId(bookingId)).thenReturn(Optional.empty());
		when(paymentOrders.saveAndFlush(any(PaymentOrder.class)))
			.thenAnswer(invocation -> invocation.getArgument(0));

		PaymentOrderResponse response = service.createOrder(ownerId, bookingId);

		assertThat(response.amount()).isEqualByComparingTo("550.00");
	}

	@Test
	void workerConfirmationCreatesANinetyPercentSettlementAndKeepsTenPercentWarrantyRetention() {
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
		when(warrantyRetentions.existsByPaymentOrderId(orderId)).thenReturn(false);
		when(warrantyRetentions.saveAndFlush(any(WarrantyRetention.class)))
			.thenAnswer(invocation -> invocation.getArgument(0));

		PaymentOrderResponse response = service.confirmOfflineReceipt(workerId, orderId);

		assertThat(response.status()).isEqualTo(PaymentOrderStatus.PAID);
		ArgumentCaptor<Settlement> captor = ArgumentCaptor.forClass(Settlement.class);
		verify(settlements).saveAndFlush(captor.capture());
		assertThat(captor.getValue().getStatus()).isEqualTo(SettlementStatus.SETTLEABLE);
		assertThat(captor.getValue().getAmount()).isEqualByComparingTo("324.00");
		assertThat(response.workerSettlement()).isEqualByComparingTo("324.00");
		assertThat(response.warrantyRetention()).isEqualByComparingTo("36.00");
		ArgumentCaptor<WarrantyRetention> warrantyCaptor =
			ArgumentCaptor.forClass(WarrantyRetention.class);
		verify(warrantyRetentions).saveAndFlush(warrantyCaptor.capture());
		assertThat(warrantyCaptor.getValue().getStatus())
			.isEqualTo(WarrantyRetentionStatus.HELD);
		assertThat(warrantyCaptor.getValue().getAmount())
			.isEqualByComparingTo("36.00");
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

	@Test
	void splitPaymentNeedsWorkerReceiptAndAdminFeeVerification() {
		UUID orderId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		UUID adminId = UUID.randomUUID();
		PaymentOrder order = PaymentOrder.createSplitOffline(
			UUID.randomUUID(), ownerId, workerId, UUID.randomUUID(),
			new BigDecimal("500.00"));
		ReflectionTestUtils.setField(order, "id", orderId);
		when(paymentOrders.findByIdForUpdate(orderId)).thenReturn(Optional.of(order));
		when(paymentOrders.saveAndFlush(order)).thenReturn(order);
		when(paymentOrders.existsReferenceOnOtherOrder(any(), any()))
			.thenReturn(false);

		PaymentOrderResponse reported = service.reportSplitOfflinePayments(
			ownerId, orderId, "银行卡转账", "worker-ref-1",
			"对公转账", "platform-ref-1", null);
		assertThat(reported.status()).isEqualTo(PaymentOrderStatus.UNDER_REVIEW);
		verify(paymentOrders).findByIdForUpdate(orderId);

		PaymentOrderResponse workerConfirmed =
			service.confirmConstructionReceipt(workerId, orderId);
		assertThat(workerConfirmed.status()).isEqualTo(PaymentOrderStatus.UNDER_REVIEW);

		PaymentOrderResponse paid = service.verifyPlatformFee(
			adminId, orderId, true, null);
		assertThat(paid.status()).isEqualTo(PaymentOrderStatus.PAID);
		verify(paymentOrders, times(3)).findByIdForUpdate(orderId);
		verify(settlements, never()).saveAndFlush(any());
		verify(warrantyRetentions, never()).saveAndFlush(any());
		verify(workerWarrantyAccounts).createContributionForPaidOrder(
			workerId, orderId, order.getBookingId(), new BigDecimal("500.00"));
	}

	@Test
	void platformFeeResubmissionDoesNotUndoConfirmedConstructionReceipt() {
		UUID adminId = UUID.randomUUID();
		PaymentOrder order = PaymentOrder.createSplitOffline(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			new BigDecimal("10840.00"));
		order.reportSplitOfflinePayments(
			"微信转账", "worker-ref-1", "对公转账", "fee-ref-1", null);
		order.confirmConstructionReceipt();
		order.verifyPlatformFee(false, adminId, "平台流水号无法核对");

		order.reportSplitOfflinePayments(
			"微信转账", "worker-ref-1", "对公转账", "fee-ref-2", "重新提交平台费");

		assertThat(order.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.CONFIRMED);
		assertThat(order.getConstructionPaymentReference()).isEqualTo("worker-ref-1");
		assertThat(order.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.REPORTED);
		assertThat(order.getPlatformFeeReference()).isEqualTo("fee-ref-2");
		assertThat(order.getStatus()).isEqualTo(PaymentOrderStatus.UNDER_REVIEW);
	}

	@Test
	void maliciousPartialPayloadCannotReplaceConfirmedConstructionReference() {
		UUID orderId = UUID.randomUUID();
		UUID ownerId = UUID.randomUUID();
		PaymentOrder order = PaymentOrder.createSplitOffline(
			UUID.randomUUID(), ownerId, UUID.randomUUID(), UUID.randomUUID(),
			new BigDecimal("10840.00"));
		ReflectionTestUtils.setField(order, "id", orderId);
		order.reportSplitOfflinePayments(
			"微信转账", "worker-ref-1", "对公转账", "fee-ref-1", null);
		order.confirmConstructionReceipt();
		order.verifyPlatformFee(false, UUID.randomUUID(), "平台流水号无法核对");
		when(paymentOrders.findByIdForUpdate(orderId)).thenReturn(Optional.of(order));
		when(paymentOrders.saveAndFlush(order)).thenReturn(order);
		when(paymentOrders.existsReferenceOnOtherOrder(any(), any()))
			.thenReturn(false);

		assertThatThrownBy(() -> service.reportSplitOfflinePayments(
			ownerId, orderId,
			"现金", "tampered-worker-ref",
			"对公转账", "fee-ref-2", "恶意局部报备"))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("INVALID_STATUS"));

		assertThat(order.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.CONFIRMED);
		assertThat(order.getConstructionPaymentReference()).isEqualTo("worker-ref-1");
		assertThat(order.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.REJECTED);
		assertThat(order.getPlatformFeeReference()).isEqualTo("fee-ref-1");
		verify(paymentOrders, never()).saveAndFlush(order);
	}
}
