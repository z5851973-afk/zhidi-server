package com.zhidi.server.dailyreport;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingService;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class DailyReportIntegrationTest extends MySqlContainerSupport {

	@Autowired
	DailyReportService reportService;

	@Autowired
	BookingService bookingService;

	@Autowired
	DailyReportRepository reportRepository;

	@Autowired
	BookingRepository bookings;

	@Autowired
	ServiceRequestRepository serviceRequests;

	@Autowired
	UserRepository users;

	@Autowired
	WorkerProfileRepository workerProfiles;

	@Autowired
	OwnerProfileRepository ownerProfiles;

	private User owner;
	private User worker;

	@BeforeEach
	void cleanDatabase() {
		reportRepository.deleteAll();
		bookings.deleteAll();
		serviceRequests.deleteAll();
		workerProfiles.deleteAll();
		ownerProfiles.deleteAll();
		users.deleteAll();

		owner = createUser("13800138210", UserRole.OWNER);
		worker = createUser("13800138211", UserRole.WORKER);

		ownerProfiles.saveAndFlush(OwnerProfile.create(owner.getId(),
			"张业主", "杭州", "新房装修", "余杭区", new BigDecimal("120.00")));
		workerProfiles.saveAndFlush(WorkerProfile.create(worker.getId(),
			"李师傅", "杭州", "木工", 8, new BigDecimal("500.00"), "木工经验丰富"));
	}

	@Test
	void submitDailyReportForHiredBookingSucceeds() {
		UUID bookingId = createHiredBooking();

		DailyReportRequest request = new DailyReportRequest(
			LocalDate.now(), "今日完成客厅吊顶安装", List.of("https://img.example.com/1.jpg"));

		DailyReportResponse response = reportService.submit(
			worker.getId(), bookingId, request);

		assertThat(response.content()).isEqualTo("今日完成客厅吊顶安装");
		assertThat(response.photos()).containsExactly("https://img.example.com/1.jpg");
		assertThat(response.reportDate()).isEqualTo(LocalDate.now());
	}

	@Test
	void submitDailyReportForSameDayUpdatesExisting() {
		UUID bookingId = createHiredBooking();
		LocalDate today = LocalDate.now();

		reportService.submit(worker.getId(), bookingId,
			new DailyReportRequest(today, "第一版内容", null));

		DailyReportResponse updated = reportService.submit(worker.getId(), bookingId,
			new DailyReportRequest(today, "更新后的内容", List.of("https://img.example.com/2.jpg")));

		assertThat(updated.content()).isEqualTo("更新后的内容");
		assertThat(updated.photos()).hasSize(1);

		List<DailyReportResponse> reports = reportService.findByBooking(bookingId);
		assertThat(reports).hasSize(1);
	}

	@Test
	void submitDailyReportForNonHiredBookingFails() {
		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "测试")).getId();

		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker.getId(), "李师傅"));
		booking.accept();
		bookings.saveAndFlush(booking);

		Throwable error = catchThrowable(() ->
			reportService.submit(worker.getId(), booking.getId(),
				new DailyReportRequest(LocalDate.now(), "测试内容", null)));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(409);
			assertThat(ex.code()).isEqualTo("INVALID_STATUS");
		});
	}

	@Test
	void findByBookingReturnsReportsInDescOrder() {
		UUID bookingId = createHiredBooking();
		LocalDate today = LocalDate.now();

		reportService.submit(worker.getId(), bookingId,
			new DailyReportRequest(today.minusDays(1), "前一天内容", null));
		reportService.submit(worker.getId(), bookingId,
			new DailyReportRequest(today, "当天内容", null));

		List<DailyReportResponse> reports = reportService.findByBooking(bookingId);
		assertThat(reports).hasSize(2);
		assertThat(reports.get(0).reportDate()).isEqualTo(today);
		assertThat(reports.get(1).reportDate()).isEqualTo(today.minusDays(1));
	}

	private UUID createHiredBooking() {
		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "测试木工")).getId();

		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker.getId(), "李师傅"));
		booking.accept();
		bookings.saveAndFlush(booking);

		Instant proposedTime = Instant.now().plus(1, ChronoUnit.DAYS)
			.truncatedTo(ChronoUnit.MINUTES);
		bookingService.proposeVisit(worker.getId(), booking.getId(), proposedTime);
		bookingService.acceptVisit(owner.getId(), booking.getId());
		bookingService.arrive(worker.getId(), booking.getId(), true);
		bookingService.arrive(owner.getId(), booking.getId(), false);
		booking.hire();
		return bookings.saveAndFlush(booking).getId();
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
