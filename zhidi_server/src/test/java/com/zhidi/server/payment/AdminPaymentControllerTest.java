package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import com.zhidi.server.account.UserRole;
import com.zhidi.server.audit.OperationLog;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class AdminPaymentControllerTest {

	@Test
	void platformFeeVerificationWritesAnAuditLogWithoutBankAccountDetails() {
		PaymentOrderService service = mock(PaymentOrderService.class);
		OperationLogRepository logs = mock(OperationLogRepository.class);
		AdminPaymentController controller = new AdminPaymentController(service, logs);
		UUID adminId = UUID.randomUUID();
		UUID orderId = UUID.randomUUID();

		controller.verifyPlatformFee(
			new CurrentUserPrincipal(adminId, "13800138000", Set.of(UserRole.ADMIN)),
			orderId, new AdminPaymentController.VerifyPlatformFeeRequest(true, null));

		verify(service).verifyPlatformFee(adminId, orderId, true, null);
		ArgumentCaptor<OperationLog> captor = ArgumentCaptor.forClass(OperationLog.class);
		verify(logs).save(captor.capture());
		assertThat(captor.getValue().getAction())
			.isEqualTo("ADMIN_PLATFORM_FEE_APPROVE");
		assertThat(captor.getValue().getTargetId()).isEqualTo(orderId.toString());
		assertThat(captor.getValue().getDetailJson()).doesNotContain("account");
	}
}
