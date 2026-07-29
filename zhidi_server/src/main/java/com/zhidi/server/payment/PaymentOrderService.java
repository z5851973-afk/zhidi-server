package com.zhidi.server.payment;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.inspection.InspectionNode;
import com.zhidi.server.inspection.InspectionNodeRepository;
import com.zhidi.server.inspection.InspectionNodeStatus;
import com.zhidi.server.quote.Quote;
import com.zhidi.server.quote.QuoteItem;
import com.zhidi.server.quote.QuoteRepository;
import com.zhidi.server.quote.QuoteStatus;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PaymentOrderService {

	private final PaymentOrderRepository paymentOrders;
	private final BookingRepository bookings;
	private final QuoteRepository quotes;
	private final InspectionNodeRepository inspectionNodes;
	private final SettlementRepository settlements;

	public PaymentOrderService(PaymentOrderRepository paymentOrders,
			BookingRepository bookings, QuoteRepository quotes,
			InspectionNodeRepository inspectionNodes,
			SettlementRepository settlements) {
		this.paymentOrders = paymentOrders;
		this.bookings = bookings;
		this.quotes = quotes;
		this.inspectionNodes = inspectionNodes;
		this.settlements = settlements;
	}

	@Transactional
	public PaymentOrderResponse createOrder(UUID ownerUserId, UUID bookingId) {
		Booking booking = bookings.findById(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));

		if (!booking.getOwnerUserId().equals(ownerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_OWNER", "只有业主才能创建支付订单");
		}

		if (booking.getStatus() != BookingStatus.HIRED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有在 HIRED 状态下才能创建支付订单");
		}

		List<InspectionNode> nodes =
			inspectionNodes.findByBookingIdOrderBySortOrderAsc(bookingId);
		if (nodes.isEmpty()) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INSPECTION_REQUIRED", "请先创建并完成验收节点");
		}
		if (nodes.stream().anyMatch(node ->
				node.getStatus() != InspectionNodeStatus.PASSED)) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INSPECTION_NOT_PASSED", "全部验收节点通过后才能付款");
		}

		// 查找已存在的支付订单，防止重复创建
		paymentOrders.findByBookingId(bookingId).ifPresent(existing -> {
			throw new BusinessException(HttpStatus.CONFLICT,
				"ORDER_EXISTS", "该预约已有支付订单");
		});

		// 找到该 booking 下已接受的报价
		List<Quote> bookingQuotes = quotes.findByBookingIdOrderByCreatedAtDesc(bookingId);
		Quote acceptedQuote = bookingQuotes.stream()
			.filter(q -> q.getStatus() == QuoteStatus.ACCEPTED)
			.findFirst()
			.orElseThrow(() -> new BusinessException(HttpStatus.BAD_REQUEST,
				"NO_ACCEPTED_QUOTE", "没有已接受的报价，无法创建支付订单"));

		BigDecimal total = acceptedQuote.getItems().stream()
			.map(QuoteItem::subtotal)
			.reduce(BigDecimal.ZERO, BigDecimal::add);

		if (total.compareTo(BigDecimal.ZERO) <= 0) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_AMOUNT", "报价总价必须大于 0");
		}

		PaymentOrder order = PaymentOrder.createOffline(
			booking.getId(), ownerUserId, booking.getWorkerUserId(),
			acceptedQuote.getId(), total);

		return PaymentOrderResponse.from(paymentOrders.saveAndFlush(order));
	}

	@Transactional
	public PaymentOrderResponse reportOfflinePayment(UUID ownerUserId, UUID orderId,
			String channel, String reference, String note) {
		PaymentOrder order = findVisibleOrder(ownerUserId, orderId);
		if (!order.getOwnerUserId().equals(ownerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_OWNER", "只有业主才能报告付款");
		}
		if (order.getStatus() == PaymentOrderStatus.OWNER_REPORTED_PAID) {
			return PaymentOrderResponse.from(order);
		}
		try {
			order.reportOfflinePayment(channel, reference, note);
		} catch (IllegalArgumentException ex) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_PAYMENT_REPORT", ex.getMessage());
		} catch (IllegalStateException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", ex.getMessage());
		}
		return PaymentOrderResponse.from(paymentOrders.saveAndFlush(order));
	}

	@Transactional
	public PaymentOrderResponse confirmOfflineReceipt(UUID workerUserId,
			UUID orderId) {
		PaymentOrder order = findVisibleOrder(workerUserId, orderId);
		if (!order.getWorkerUserId().equals(workerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_WORKER", "只有接单工人才能确认收款");
		}
		if (order.getStatus() == PaymentOrderStatus.PAID
				&& order.getWorkerConfirmedReceivedAt() != null) {
			return PaymentOrderResponse.from(order);
		}
		try {
			order.confirmOfflineReceipt();
		} catch (IllegalStateException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", ex.getMessage());
		}
		PaymentOrder saved = paymentOrders.saveAndFlush(order);
		if (settlements.findByPaymentOrderId(orderId).isEmpty()) {
			Settlement settlement = Settlement.create(
				saved.getWorkerUserId(), saved.getBookingId(), saved.getId(),
				saved.getWorkerSettlement());
			settlement.markSettleable();
			settlement.markSettled();
			settlements.saveAndFlush(settlement);
		}
		return PaymentOrderResponse.from(saved);
	}

	@Transactional(readOnly = true)
	public PaymentOrderResponse getOrder(UUID userId, UUID orderId) {
		return PaymentOrderResponse.from(findVisibleOrder(userId, orderId));
	}

	@Transactional(readOnly = true)
	public Page<PaymentOrderResponse> listOrdersForUser(UUID userId, Pageable pageable) {
		return paymentOrders.findByUserId(userId, pageable)
			.map(PaymentOrderResponse::from);
	}

	@Transactional
	public PaymentOrderResponse markPaid(UUID orderId, String transactionId,
			String paymentMethod) {
		PaymentOrder order = paymentOrders.findById(orderId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"ORDER_NOT_FOUND", "支付订单不存在"));

		if (order.getStatus() != PaymentOrderStatus.PENDING) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有待支付订单才能标记已支付");
		}

		order.markPaid(transactionId, paymentMethod);
		return PaymentOrderResponse.from(paymentOrders.saveAndFlush(order));
	}

	@Transactional
	public PaymentOrderResponse requestRefund(UUID ownerUserId, UUID orderId,
			String reason) {
		PaymentOrder order = paymentOrders.findById(orderId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"ORDER_NOT_FOUND", "支付订单不存在"));

		if (!order.getOwnerUserId().equals(ownerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_OWNER", "只有业主才能申请退款");
		}

		if (order.getStatus() != PaymentOrderStatus.PAID) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有已支付订单才能申请退款");
		}
		throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE,
			"REFUND_PROVIDER_NOT_CONFIGURED", "退款渠道尚未开通");
	}

	private PaymentOrder findVisibleOrder(UUID userId, UUID orderId) {
		PaymentOrder order = paymentOrders.findById(orderId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"ORDER_NOT_FOUND", "支付订单不存在"));
		if (!order.getOwnerUserId().equals(userId)
				&& !order.getWorkerUserId().equals(userId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"ORDER_NOT_FOUND", "支付订单不存在");
		}
		return order;
	}
}
