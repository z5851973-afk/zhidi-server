package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class OfflinePaymentInstructionsServiceTest {

	private final PaymentOrderRepository paymentOrders = mock(PaymentOrderRepository.class);
	private final WorkerProfileRepository workerProfiles = mock(WorkerProfileRepository.class);
	private UUID ownerId;
	private UUID workerId;
	private UUID orderId;
	private PaymentOrder order;

	@BeforeEach
	void setUp() {
		ownerId = UUID.randomUUID();
		workerId = UUID.randomUUID();
		orderId = UUID.randomUUID();
		order = PaymentOrder.createSplitOffline(
			UUID.randomUUID(), ownerId, workerId, UUID.randomUUID(),
			new BigDecimal("10840.00"));
		when(paymentOrders.findById(orderId)).thenReturn(Optional.of(order));
		when(workerProfiles.findByUserId(workerId)).thenReturn(Optional.of(
			WorkerProfile.create(workerId, "张师傅", "成都", "木工", 8,
				new BigDecimal("500.00"), "木工施工")));
	}

	@Test
	void missingCompanyAccountConfigurationBlocksPaymentInstructions() {
		OfflinePaymentInstructionsService service = serviceWith(
			new OfflinePaymentProperties("", "", ""));

		assertThatThrownBy(() -> service.get(ownerId, orderId))
			.isInstanceOfSatisfying(BusinessException.class, ex -> {
				assertThat(ex.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
				assertThat(ex.code()).isEqualTo(
					"OFFLINE_PAYMENT_INSTRUCTIONS_NOT_CONFIGURED");
			});
	}

	@Test
	void returnsWorkerRouteAndCompanyAccountWithoutInventingWorkerBankDetails() {
		OfflinePaymentInstructionsService service = serviceWith(
			new OfflinePaymentProperties("知底科技有限公司", "中国银行成都分行",
				"1234567890"));

		OfflinePaymentInstructionsResponse response = service.get(ownerId, orderId);

		assertThat(response.quoteAmount()).isEqualByComparingTo("10840.00");
		assertThat(response.platformFee()).isEqualByComparingTo("1084.00");
		assertThat(response.constructionPayment().amount())
			.isEqualByComparingTo("10840.00");
		assertThat(response.constructionPayment().workerName()).isEqualTo("张师傅");
		assertThat(response.constructionPayment().contactAction())
			.isEqualTo("CONTACT_WORKER_IN_APP");
		assertThat(response.platformFeePayment().accountName())
			.isEqualTo("知底科技有限公司");
		assertThat(response.platformFeePayment().bankAccount())
			.isEqualTo("1234567890");
	}

	private OfflinePaymentInstructionsService serviceWith(
			OfflinePaymentProperties properties) {
		return new OfflinePaymentInstructionsService(
			paymentOrders, workerProfiles, properties);
	}
}
