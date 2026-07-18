package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

import com.zhidi.server.common.error.BusinessException;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class PaymentControllerTest {

	@Test
	void callbackCannotMarkOrderPaidBeforeProviderIsConfigured() {
		PaymentOrderService service = mock(PaymentOrderService.class);
		PaymentController controller = new PaymentController(service);

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
