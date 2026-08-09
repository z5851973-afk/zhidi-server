package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import com.zhidi.server.payment.provider.UnconfiguredWechatPaymentProvider;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class WechatPaymentControllerTest {

	@Test
	void unconfiguredWechatIntentReturnsExplicitServiceUnavailableWithoutFakeData() {
		WechatPaymentController controller = new WechatPaymentController(
			new UnconfiguredWechatPaymentProvider());
		CurrentUserPrincipal owner = new CurrentUserPrincipal(
			UUID.randomUUID(), "13800000000", Set.of(UserRole.OWNER));

		org.assertj.core.api.Assertions.assertThatThrownBy(() ->
			controller.createIntent(owner, UUID.randomUUID()))
			.isInstanceOfSatisfying(BusinessException.class, ex -> {
				assertThat(ex.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
				assertThat(ex.code()).isEqualTo("PAYMENT_PROVIDER_NOT_CONFIGURED");
				assertThat(ex.getMessage()).doesNotContain("transactionId");
			});
	}
}
