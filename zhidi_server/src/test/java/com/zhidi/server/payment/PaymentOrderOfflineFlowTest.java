package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class PaymentOrderOfflineFlowTest {

	@Test
	void offlineOrderDoesNotPretendToChargeAPlatformFee() {
		PaymentOrder order = PaymentOrder.createOffline(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("1200.00"));

		assertThat(order.getPaymentMethod()).isEqualTo("OFFLINE");
		assertThat(order.getPlatformFee()).isEqualByComparingTo("0.00");
		assertThat(order.getWorkerSettlement()).isEqualByComparingTo("1200.00");
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

	private static PaymentOrder offlineOrder() {
		return PaymentOrder.createOffline(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("88.00"));
	}
}
