package com.zhidi.server.payment;

import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OfflinePaymentInstructionsService {

	private final PaymentOrderRepository paymentOrders;
	private final WorkerProfileRepository workerProfiles;
	private final OfflinePaymentProperties properties;

	public OfflinePaymentInstructionsService(PaymentOrderRepository paymentOrders,
			WorkerProfileRepository workerProfiles,
			OfflinePaymentProperties properties) {
		this.paymentOrders = paymentOrders;
		this.workerProfiles = workerProfiles;
		this.properties = properties;
	}

	@Transactional(readOnly = true)
	public OfflinePaymentInstructionsResponse get(UUID ownerUserId, UUID orderId) {
		PaymentOrder order = paymentOrders.findById(orderId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"ORDER_NOT_FOUND", "支付订单不存在"));
		if (!order.getOwnerUserId().equals(ownerUserId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"ORDER_NOT_FOUND", "支付订单不存在");
		}
		if (order.getFundingModel() != PaymentFundingModel.OFFLINE_SPLIT_V2) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"PAYMENT_FLOW_MISMATCH", "该订单不使用两笔线下付款流程");
		}
		if (!properties.hasCompanyAccount()) {
			throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE,
				"OFFLINE_PAYMENT_INSTRUCTIONS_NOT_CONFIGURED",
				"平台服务费收款账户尚未配置");
		}

		String workerName = workerProfiles.findByUserId(order.getWorkerUserId())
			.map(profile -> profile.getName() == null || profile.getName().isBlank()
				? "本单师傅" : profile.getName())
			.orElse("本单师傅");
		return new OfflinePaymentInstructionsResponse(
			orderId, order.getQuoteAmount(), order.getPlatformFee(),
			new OfflinePaymentInstructionsResponse.ConstructionPaymentInstruction(
				order.getQuoteAmount(), workerName, "CONTACT_WORKER_IN_APP"),
			new OfflinePaymentInstructionsResponse.PlatformFeePaymentInstruction(
				order.getPlatformFee(), properties.companyAccountName(),
				properties.companyBankName(), properties.companyBankAccount()));
	}
}
