package com.zhidi.server.payment;

import com.zhidi.server.common.error.BusinessException;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SettlementService {

	private final SettlementRepository settlements;
	private final PaymentOrderRepository paymentOrders;

	public SettlementService(SettlementRepository settlements,
			PaymentOrderRepository paymentOrders) {
		this.settlements = settlements;
		this.paymentOrders = paymentOrders;
	}

	/**
	 * 支付成功后自动创建结算记录（由 PaymentOrderService.markPaid 成功后调用）。
	 */
	@Transactional
	public SettlementResponse createForPayment(UUID paymentOrderId) {
		PaymentOrder order = paymentOrders.findById(paymentOrderId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"ORDER_NOT_FOUND", "支付订单不存在"));

		if (order.getStatus() != PaymentOrderStatus.PAID) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有已支付订单才能生成结算");
		}

		// 防止重复创建
		settlements.findByPaymentOrderId(paymentOrderId).ifPresent(existing -> {
			throw new BusinessException(HttpStatus.CONFLICT,
				"SETTLEMENT_EXISTS", "该支付订单已有结算记录");
		});

		Settlement settlement = Settlement.create(
			order.getWorkerUserId(), order.getBookingId(),
			order.getId(), order.getWorkerSettlement());

		return SettlementResponse.from(settlements.saveAndFlush(settlement));
	}

	@Transactional(readOnly = true)
	public SettlementResponse getSettlement(UUID settlementId) {
		Settlement settlement = settlements.findById(settlementId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"SETTLEMENT_NOT_FOUND", "结算记录不存在"));
		return SettlementResponse.from(settlement);
	}

	@Transactional
	public SettlementResponse markSettleable(UUID settlementId) {
		Settlement settlement = settlements.findById(settlementId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"SETTLEMENT_NOT_FOUND", "结算记录不存在"));
		settlement.markSettleable();
		return SettlementResponse.from(settlements.saveAndFlush(settlement));
	}

	@Transactional
	public SettlementResponse markSettled(UUID settlementId) {
		// TODO: 对接提现渠道 — 在标记已结算前，需通过银行/微信/支付宝提现接口完成实际打款
		// 当前实现仅更新状态，正式上线前必须对接真实的提现 API
		Settlement settlement = settlements.findById(settlementId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"SETTLEMENT_NOT_FOUND", "结算记录不存在"));
		settlement.markSettled();
		return SettlementResponse.from(settlements.saveAndFlush(settlement));
	}

	@Transactional
	public SettlementResponse freeze(UUID settlementId, String reason) {
		if (reason == null || reason.isBlank()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"REASON_REQUIRED", "冻结原因不能为空");
		}
		Settlement settlement = settlements.findById(settlementId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"SETTLEMENT_NOT_FOUND", "结算记录不存在"));
		settlement.freeze(reason.trim());
		return SettlementResponse.from(settlements.saveAndFlush(settlement));
	}

	@Transactional(readOnly = true)
	public List<SettlementResponse> listForWorker(UUID workerUserId) {
		return settlements.findByWorkerUserIdOrderByCreatedAtDesc(workerUserId)
			.stream().map(SettlementResponse::from).toList();
	}
}
