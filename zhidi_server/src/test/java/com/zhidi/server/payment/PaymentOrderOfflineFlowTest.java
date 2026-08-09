package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

class PaymentOrderOfflineFlowTest {

	@Test
	void offlineOrderAddsTenPercentPlatformFeeToOwnerPayableAmount() {
		PaymentOrder order = PaymentOrder.createOffline(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("1200.00"));

		assertThat(order.getPaymentMethod()).isEqualTo("OFFLINE");
		assertThat(order.getAmount()).isEqualByComparingTo("1320.00");
		assertThat(order.getPlatformFee()).isEqualByComparingTo("120.00");
		assertThat(order.getWorkerSettlement()).isEqualByComparingTo("1080.00");
		assertThat(order.getWarrantyRetention()).isEqualByComparingTo("120.00");
		assertThat(order.getStatus()).isEqualTo(PaymentOrderStatus.PENDING);
	}

	@Test
	void ownerReportDoesNotMarkMoneyAsReceived() {
		PaymentOrder order = offlineOrder();

		order.reportOfflinePayment("银行卡转账", "尾号 2318", "已当面转账");

		assertThat(order.getStatus())
			.isEqualTo(PaymentOrderStatus.OWNER_REPORTED_PAID);
		assertThat(order.getOwnerReportedPaidAt()).isNotNull();
		assertThat(order.getPaidAt()).isNull();
		assertThat(order.getOfflinePaymentChannel()).isEqualTo("银行卡转账");
		assertThat(order.getPaymentReference()).isEqualTo("尾号 2318");
		assertThat(order.getOwnerPaymentNote()).isEqualTo("已当面转账");
	}

	@Test
	void workerMustConfirmReceiptBeforeOrderIsPaid() {
		PaymentOrder order = offlineOrder();

		assertThatThrownBy(order::confirmOfflineReceipt)
			.isInstanceOf(IllegalStateException.class);

		order.reportOfflinePayment("现金", null, null);
		order.confirmOfflineReceipt();

		assertThat(order.getStatus()).isEqualTo(PaymentOrderStatus.PAID);
		assertThat(order.getWorkerConfirmedReceivedAt()).isNotNull();
		assertThat(order.getPaidAt()).isNotNull();
	}

	@Test
	void splitOfflineOrderPaysTheFullQuoteToWorkerAndKeepsWarrantySeparate() {
		PaymentOrder order = PaymentOrder.createSplitOffline(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("10840.00"));

		assertThat(order.getFundingModel())
			.isEqualTo(PaymentFundingModel.OFFLINE_SPLIT_V2);
		assertThat(order.getQuoteAmount()).isEqualByComparingTo("10840.00");
		assertThat(order.getAmount()).isEqualByComparingTo("11924.00");
		assertThat(order.getPlatformFee()).isEqualByComparingTo("1084.00");
		assertThat(order.getWorkerSettlement()).isEqualByComparingTo("10840.00");
		assertThat(order.getWarrantyRetention()).isEqualByComparingTo("0.00");
	}

	@Test
	void splitOfflineOrderIsPaidOnlyAfterWorkerAndPlatformConfirmTheirComponents() {
		PaymentOrder order = PaymentOrder.createSplitOffline(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("1000.00"));

		order.reportSplitOfflinePayments(
			"银行卡转账", "worker-ref-1",
			"对公转账", "platform-ref-1", "两笔已转账");

		assertThat(order.getStatus()).isEqualTo(PaymentOrderStatus.UNDER_REVIEW);
		assertThat(order.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.REPORTED);
		assertThat(order.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.REPORTED);
		assertThat(order.getPaidAt()).isNull();

		order.confirmConstructionReceipt();

		assertThat(order.getStatus()).isEqualTo(PaymentOrderStatus.UNDER_REVIEW);
		assertThat(order.getPaidAt()).isNull();

		UUID adminId = UUID.randomUUID();
		order.verifyPlatformFee(true, adminId, null);

		assertThat(order.getStatus()).isEqualTo(PaymentOrderStatus.PAID);
		assertThat(order.getPlatformFeeVerifiedBy()).isEqualTo(adminId);
		assertThat(order.getPaidAt()).isNotNull();
	}

	@Test
	void rejectedPlatformFeeCanBeResubmittedWithoutRepeatingConfirmedConstruction() {
		PaymentOrder order = splitOrder();
		order.reportSplitOfflinePayments(
			"银行卡转账", "worker-ref-1", "对公转账", "fee-ref-1", null);
		order.confirmConstructionReceipt();
		order.verifyPlatformFee(false, UUID.randomUUID(), "流水号无法核对");

		order.reportSplitOfflinePayments(
			null, null, "对公转账", "fee-ref-2", "只重报服务费");

		assertThat(order.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.CONFIRMED);
		assertThat(order.getConstructionPaymentReference()).isEqualTo("worker-ref-1");
		assertThat(order.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.REPORTED);
		assertThat(order.getPlatformFeeReference()).isEqualTo("fee-ref-2");
		assertThat(order.getStatus()).isEqualTo(PaymentOrderStatus.UNDER_REVIEW);
	}

	@Test
	void rejectedConstructionCanBeResubmittedWithoutRepeatingVerifiedPlatformFee() {
		PaymentOrder order = splitOrder();
		order.reportSplitOfflinePayments(
			"银行卡转账", "worker-ref-1", "对公转账", "fee-ref-1", null);
		order.verifyPlatformFee(true, UUID.randomUUID(), null);
		ReflectionTestUtils.setField(order, "constructionPaymentStatus",
			PaymentComponentStatus.REJECTED);

		order.reportSplitOfflinePayments(
			"微信转账", "worker-ref-2", null, null, "只重报工程款");

		assertThat(order.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.REPORTED);
		assertThat(order.getConstructionPaymentReference()).isEqualTo("worker-ref-2");
		assertThat(order.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.VERIFIED);
		assertThat(order.getPlatformFeeReference()).isEqualTo("fee-ref-1");
		assertThat(order.getStatus()).isEqualTo(PaymentOrderStatus.UNDER_REVIEW);
	}

	@Test
	void identicalSplitReportRetryIsIdempotent() {
		PaymentOrder order = splitOrder();
		order.reportSplitOfflinePayments(
			"银行卡转账", "worker-ref-1", "对公转账", "fee-ref-1", null);
		Instant constructionReportedAt = order.getConstructionReportedAt();
		Instant platformReportedAt = order.getPlatformFeeReportedAt();

		order.reportSplitOfflinePayments(
			"银行卡转账", "worker-ref-1", "对公转账", "fee-ref-1", null);

		assertThat(order.getConstructionReportedAt()).isSameAs(constructionReportedAt);
		assertThat(order.getPlatformFeeReportedAt()).isSameAs(platformReportedAt);
		assertThat(order.getStatus()).isEqualTo(PaymentOrderStatus.UNDER_REVIEW);
	}

	@Test
	void confirmedConstructionReferenceCannotBeChangedByPartialResubmission() {
		PaymentOrder order = splitOrder();
		order.reportSplitOfflinePayments(
			"银行卡转账", "worker-ref-1", "对公转账", "fee-ref-1", null);
		order.confirmConstructionReceipt();
		order.verifyPlatformFee(false, UUID.randomUUID(), "平台流水号无法核对");

		assertThatThrownBy(() -> order.reportSplitOfflinePayments(
			"现金", "tampered-worker-ref",
			"对公转账", "fee-ref-2", "恶意混入终态组件"))
			.isInstanceOf(IllegalStateException.class)
			.hasMessageContaining("工程款")
			.hasMessageContaining("不能重复修改");

		assertThat(order.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.CONFIRMED);
		assertThat(order.getConstructionPaymentReference()).isEqualTo("worker-ref-1");
		assertThat(order.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.REJECTED);
		assertThat(order.getPlatformFeeReference()).isEqualTo("fee-ref-1");
	}

	@Test
	void verifiedPlatformReferenceCannotBeChangedByPartialResubmission() {
		PaymentOrder order = splitOrder();
		order.reportSplitOfflinePayments(
			"银行卡转账", "worker-ref-1", "对公转账", "fee-ref-1", null);
		order.verifyPlatformFee(true, UUID.randomUUID(), null);
		ReflectionTestUtils.setField(order, "constructionPaymentStatus",
			PaymentComponentStatus.REJECTED);
		ReflectionTestUtils.setField(order, "status",
			PaymentOrderStatus.PARTIALLY_REPORTED);

		assertThatThrownBy(() -> order.reportSplitOfflinePayments(
			"银行卡转账", "worker-ref-2",
			"现金", "tampered-fee-ref", "恶意混入终态组件"))
			.isInstanceOf(IllegalStateException.class)
			.hasMessageContaining("平台服务费")
			.hasMessageContaining("不能重复修改");

		assertThat(order.getConstructionPaymentStatus())
			.isEqualTo(PaymentComponentStatus.REJECTED);
		assertThat(order.getConstructionPaymentReference()).isEqualTo("worker-ref-1");
		assertThat(order.getPlatformFeeStatus())
			.isEqualTo(PaymentComponentStatus.VERIFIED);
		assertThat(order.getPlatformFeeReference()).isEqualTo("fee-ref-1");
	}

	@Test
	void splitReportRequiresAtLeastOneCompleteComponent() {
		PaymentOrder order = splitOrder();

		assertThatThrownBy(() -> order.reportSplitOfflinePayments(
			null, null, null, null, null))
			.isInstanceOf(IllegalArgumentException.class)
			.hasMessageContaining("至少提交一笔");
		assertThatThrownBy(() -> order.reportSplitOfflinePayments(
			"银行卡转账", null, null, null, null))
			.isInstanceOf(IllegalArgumentException.class)
			.hasMessageContaining("付款方式和交易参考号");
	}

	private static PaymentOrder offlineOrder() {
		return PaymentOrder.createOffline(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("88.00"));
	}

	private static PaymentOrder splitOrder() {
		return PaymentOrder.createSplitOffline(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("1000.00"));
	}
}
