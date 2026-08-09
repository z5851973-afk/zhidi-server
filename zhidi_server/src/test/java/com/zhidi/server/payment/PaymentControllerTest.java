package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class PaymentControllerTest {
	private final Validator validator = Validation.buildDefaultValidatorFactory()
		.getValidator();

	@Test
	void ownerReportsBothOfflinePaymentsAndWorkerConfirmsConstructionReceipt() {
		PaymentOrderService service = mock(PaymentOrderService.class);
		OfflinePaymentInstructionsService instructions =
			mock(OfflinePaymentInstructionsService.class);
		PaymentController controller = new PaymentController(service, instructions);
		UUID ownerId = UUID.randomUUID();
		UUID workerId = UUID.randomUUID();
		UUID orderId = UUID.randomUUID();

		controller.reportSplitOfflinePayments(
			new CurrentUserPrincipal(ownerId, "13800000000", Set.of(UserRole.OWNER)),
			orderId, new PaymentController.SplitOfflinePaymentReportRequest(
				"银行卡转账", "worker-ref-1", "对公转账", "fee-ref-1", null));
		controller.confirmConstructionReceipt(
			new CurrentUserPrincipal(workerId, "13900000000", Set.of(UserRole.WORKER)),
			orderId);

		verify(service).reportSplitOfflinePayments(ownerId, orderId,
			"银行卡转账", "worker-ref-1", "对公转账", "fee-ref-1", null);
		verify(service).confirmConstructionReceipt(workerId, orderId);
	}

	@Test
	void splitReportAcceptsEitherCompleteComponentButRejectsAnEmptyBody() {
		PaymentController.SplitOfflinePaymentReportRequest platformOnly =
			new PaymentController.SplitOfflinePaymentReportRequest(
				null, null, "对公转账", "fee-ref-2", null);
		PaymentController.SplitOfflinePaymentReportRequest empty =
			new PaymentController.SplitOfflinePaymentReportRequest(
				null, null, null, null, null);

		assertThat(validator.validate(platformOnly)).isEmpty();
		assertThat(validator.validate(empty))
			.anySatisfy(violation -> assertThat(violation.getMessage())
				.contains("至少提交一笔"));
	}

	@Test
	void ownerCanRequestOrderSpecificOfflinePaymentInstructions() {
		PaymentOrderService service = mock(PaymentOrderService.class);
		OfflinePaymentInstructionsService instructions =
			mock(OfflinePaymentInstructionsService.class);
		PaymentController controller = new PaymentController(service, instructions);
		UUID ownerId = UUID.randomUUID();
		UUID orderId = UUID.randomUUID();

		controller.offlineInstructions(
			new CurrentUserPrincipal(ownerId, "13800000000", Set.of(UserRole.OWNER)),
			orderId);

		verify(instructions).get(ownerId, orderId);
	}

	@Test
	void callbackCannotMarkOrderPaidBeforeProviderIsConfigured() {
		PaymentOrderService service = mock(PaymentOrderService.class);
		PaymentController controller = new PaymentController(service,
			mock(OfflinePaymentInstructionsService.class));

		Throwable error = catchThrowable(() -> controller.paymentCallback(
			new PaymentController.PaymentCallbackRequest(
				UUID.randomUUID(), "provider-transaction", "WECHAT")));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
			assertThat(ex.code()).isEqualTo("PAYMENT_PROVIDER_NOT_CONFIGURED");
		});
		verifyNoInteractions(service);
	}
}
