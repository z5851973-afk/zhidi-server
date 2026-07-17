package com.zhidi.server.worker;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhidi.server.account.UserRepository;
import com.zhidi.server.auth.AuthService;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingService;
import com.zhidi.server.dailyreport.DailyReportRepository;
import com.zhidi.server.quote.QuoteRepository;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.workercase.WorkerCaseRepository;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.worker.WorkerProfileRepository;
import com.zhidi.server.auth.SmsVerificationCodeRepository;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.owner.OwnerProfileService;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
	"spring.autoconfigure.exclude="
		+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration",
	"auth.jwt.secret=worker-directory-controller-test-secret-at-least-thirty-two-bytes"
})
@AutoConfigureMockMvc
class WorkerDirectoryControllerTest {

	private static final UUID WORKER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000101");

	@Autowired
	MockMvc mvc;

	@MockitoBean
	WorkerProfileService workerProfileService;

	@MockitoBean
	OwnerProfileService ownerProfileService;

	@MockitoBean
	BookingService bookingService;

	@MockitoBean
	DailyReportRepository dailyReports;

	@MockitoBean
	BookingRepository bookingRepository;

	@MockitoBean
	QuoteRepository quotes;

	@MockitoBean
	ServiceRequestRepository serviceRequests;

	@MockitoBean
	WorkerCaseRepository workerCases;

	@MockitoBean
	OwnerProfileRepository ownerProfiles;

	@MockitoBean
	WorkerProfileRepository workerProfiles;

	@MockitoBean
	SmsVerificationCodeRepository smsCodes;

	@MockitoBean
	OperationLogRepository operationLogs;

	@MockitoBean
	UserRepository users;

	@MockitoBean
	AuthService authService;

	@Test
	void listsVisibleWorkersWithoutLogin() throws Exception {
		when(workerProfileService.listVisible()).thenReturn(List.of(directoryItem()));

		mvc.perform(get("/api/v1/workers"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data[0].userId").value(WORKER_ID.toString()))
			.andExpect(jsonPath("$.data[0].name").value("张师傅"))
			.andExpect(jsonPath("$.data[0].primaryTrade").value("水电"));

		verify(workerProfileService).listVisible();
	}

	@Test
	void getsVisibleWorkerDetailWithoutLogin() throws Exception {
		when(workerProfileService.getVisible(WORKER_ID)).thenReturn(directoryItem());

		mvc.perform(get("/api/v1/workers/{userId}", WORKER_ID))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.code").value("OK"))
			.andExpect(jsonPath("$.data.userId").value(WORKER_ID.toString()))
			.andExpect(jsonPath("$.data.serviceCity").value("成都"))
			.andExpect(jsonPath("$.data.dailyRate").value(180.00));

		verify(workerProfileService).getVisible(WORKER_ID);
	}

	private WorkerDirectoryResponse directoryItem() {
		return new WorkerDirectoryResponse(WORKER_ID, "张师傅", "成都", "水电",
			8, new BigDecimal("180.00"), "擅长旧房水电改造");
	}
}
