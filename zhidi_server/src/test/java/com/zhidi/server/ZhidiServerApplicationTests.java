package com.zhidi.server;

import com.zhidi.server.account.UserRepository;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.auth.AuthService;
import com.zhidi.server.auth.SmsVerificationCodeRepository;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingService;
import com.zhidi.server.dailyreport.DailyReportRepository;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.owner.OwnerProfileService;
import com.zhidi.server.quote.QuoteRepository;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.worker.WorkerProfileRepository;
import com.zhidi.server.worker.WorkerProfileService;
import com.zhidi.server.workercase.WorkerCaseRepository;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

@SpringBootTest(properties = {
	"spring.autoconfigure.exclude="
		+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
})
class ZhidiServerApplicationTests {

	@MockitoBean
	AuthService authService;

	@MockitoBean
	OwnerProfileService ownerProfileService;

	@MockitoBean
	WorkerProfileService workerProfileService;

	@MockitoBean
	BookingService bookingService;

	@MockitoBean
	BookingRepository bookingRepository;

	@MockitoBean
	DailyReportRepository dailyReports;

	@MockitoBean
	QuoteRepository quotes;

	@MockitoBean
	ServiceRequestRepository serviceRequests;

	@MockitoBean
	WorkerProfileRepository workerProfiles;

	@MockitoBean
	OwnerProfileRepository ownerProfiles;

	@MockitoBean
	WorkerCaseRepository workerCases;

	@MockitoBean
	SmsVerificationCodeRepository smsCodes;

	@MockitoBean
	OperationLogRepository operationLogs;

	@MockitoBean
	UserRepository userRepository;

	@Test
	void contextLoads() {
	}

}
