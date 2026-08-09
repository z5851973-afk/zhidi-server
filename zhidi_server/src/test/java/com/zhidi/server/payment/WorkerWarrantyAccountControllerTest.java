package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.account.UserRole;
import com.zhidi.server.audit.OperationLog;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class WorkerWarrantyAccountControllerTest {

	@Test
	void workerCanViewAccountAndReportContribution() {
		WorkerWarrantyAccountService service = mock(WorkerWarrantyAccountService.class);
		WorkerWarrantyAccountController controller =
			new WorkerWarrantyAccountController(service, configuredProperties());
		UUID workerId = UUID.randomUUID();
		UUID contributionId = UUID.randomUUID();
		CurrentUserPrincipal principal = new CurrentUserPrincipal(
			workerId, "13900000000", Set.of(UserRole.WORKER));

		controller.account(principal);
		controller.report(principal, contributionId,
			new WorkerWarrantyAccountController.ReportContributionRequest(
				"对公转账", "warranty-ref-1"));

		verify(service).getAccount(workerId);
		verify(service).reportContributionResponse(
			workerId, contributionId, "对公转账", "warranty-ref-1");
	}

	@Test
	void topUpObligationUsesAuthenticatedWorkerWithoutClientAmountOrWorkerId()
			throws NoSuchMethodException {
		WorkerWarrantyAccountService service = mock(WorkerWarrantyAccountService.class);
		WorkerWarrantyAccountController controller =
			new WorkerWarrantyAccountController(service, configuredProperties());
		UUID authenticatedWorkerId = UUID.randomUUID();
		CurrentUserPrincipal principal = new CurrentUserPrincipal(
			authenticatedWorkerId, "13900000000", Set.of(UserRole.WORKER));

		controller.topUpObligation(principal);

		verify(service).getOrCreateTopUpObligation(authenticatedWorkerId);
		assertThat(WorkerWarrantyAccountController.class
			.getDeclaredMethod("topUpObligation", CurrentUserPrincipal.class)
			.getParameterCount()).isEqualTo(1);
	}

	@Test
	void adminVerificationWritesAuditWithoutBankAccount() {
		WorkerWarrantyAccountService service = mock(WorkerWarrantyAccountService.class);
		WorkerWarrantyReleaseService releases = mock(WorkerWarrantyReleaseService.class);
		OperationLogRepository logs = mock(OperationLogRepository.class);
		AdminWorkerWarrantyController controller =
			new AdminWorkerWarrantyController(service, releases, logs);
		UUID adminId = UUID.randomUUID();
		UUID contributionId = UUID.randomUUID();
		WorkerWarrantyContributionResponse response =
			new WorkerWarrantyContributionResponse(
				contributionId, UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
				null,
				new BigDecimal("500.00"), WorkerWarrantyContributionStatus.VERIFIED,
				"对公转账", "ref", Instant.now(), adminId, Instant.now(), null,
				Instant.now(), Instant.now());
		when(service.verifyContributionResponse(
			adminId, contributionId, true, null)).thenReturn(response);

		controller.verify(
			new CurrentUserPrincipal(adminId, "13800000000", Set.of(UserRole.ADMIN)),
			contributionId,
			new AdminWorkerWarrantyController.VerifyContributionRequest(true, null));

		ArgumentCaptor<OperationLog> captor = ArgumentCaptor.forClass(OperationLog.class);
		verify(logs).save(captor.capture());
		assertThat(captor.getValue().getAction())
			.isEqualTo("ADMIN_WORKER_WARRANTY_APPROVE");
		assertThat(captor.getValue().getDetailJson()).contains("500.00");
		assertThat(captor.getValue().getDetailJson()).doesNotContain("account");
	}

	private OfflinePaymentProperties configuredProperties() {
		return new OfflinePaymentProperties(
			"知底科技", "中国银行", "company-001",
			"知底科技质保金专户", "中国银行", "warranty-001");
	}
}
