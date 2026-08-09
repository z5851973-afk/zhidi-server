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
import com.zhidi.server.notification.BusinessEvent;
import com.zhidi.server.notification.BusinessEventRepository;
import com.zhidi.server.notification.BusinessEventStreamRepository;
import com.zhidi.server.notification.BusinessEventType;
import com.zhidi.server.owner.OwnerProfile;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

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

	@Autowired
	PlatformTransactionManager transactionManager;

	@Autowired
	BusinessEventRepository businessEvents;

	@Autowired
	BusinessEventStreamRepository businessEventStreams;

	@Autowired
	com.zhidi.server.notification.BusinessEventPublisher businessEventPublisher;

	private User owner;
	private User worker;

	@BeforeEach
	void cleanDatabase() {
		businessEvents.deleteAll();
		businessEventStreams.deleteAll();
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
		String photoUrl = trustedPhotoUrl("1.jpg");

		DailyReportRequest request = new DailyReportRequest(
			LocalDate.now(), "今日完成客厅吊顶安装", List.of(photoUrl));

		DailyReportResponse response = reportService.submit(
			worker.getId(), bookingId, request);

		assertThat(response.content()).isEqualTo("今日完成客厅吊顶安装");
		assertThat(response.photos()).containsExactly(photoUrl);
		assertThat(response.reportDate()).isEqualTo(LocalDate.now());
	}

	@Test
	void submitDailyReportForSameDayAppendsAnAuditableRevision() {
		UUID bookingId = createHiredBooking();
		LocalDate today = LocalDate.now();

		DailyReportResponse first = reportService.submit(worker.getId(), bookingId,
			new DailyReportRequest(today, "第一版内容", null));

		DailyReportResponse updated = reportService.submit(worker.getId(), bookingId,
			new DailyReportRequest(today, "更新后的内容", List.of(trustedPhotoUrl("2.jpg"))));

		assertThat(first.reportRevision()).isEqualTo(1);
		assertThat(updated.reportRevision()).isEqualTo(2);
		assertThat(updated.id()).isNotEqualTo(first.id());
		assertThat(updated.content()).isEqualTo("更新后的内容");
		assertThat(updated.photos()).hasSize(1);

		List<DailyReportResponse> reports = reportService.findByBooking(
			owner.getId(), bookingId);
		assertThat(reports).hasSize(2);
		assertThat(reports.get(0).content()).isEqualTo("更新后的内容");
		assertThat(reports.get(0).reportRevision()).isEqualTo(2);
		assertThat(reports.get(1).content()).isEqualTo("第一版内容");
		assertThat(reports.get(1).reportRevision()).isEqualTo(1);

		List<BusinessEvent> notifications = businessEvents
			.findByRecipientUserIdOrderBySequenceNoAsc(owner.getId());
		assertThat(notifications)
			.extracting(BusinessEvent::getEventType)
			.containsExactly(
				BusinessEventType.DAILY_REPORT_SUBMITTED,
				BusinessEventType.DAILY_REPORT_SUBMITTED);
		assertThat(notifications)
			.extracting(BusinessEvent::getAggregateId)
			.containsExactly(first.id(), updated.id());
		assertThat(notifications)
			.extracting(event -> event.getPayload().get("revision"))
			.containsExactly(1, 2);
		assertThat(notifications)
			.allSatisfy(event -> {
				assertThat(event.getActorUserId()).isEqualTo(worker.getId());
				assertThat(event.getAggregateType()).isEqualTo("DAILY_REPORT");
				assertThat(event.getBookingId()).isEqualTo(bookingId);
				assertThat(event.getIdempotencyKey())
					.isEqualTo("daily-report:" + event.getAggregateId());
			});
	}

	@Test
	void concurrentSameDaySubmissionsReceiveDistinctRevisions() throws Exception {
		UUID bookingId = createHiredBooking();
		LocalDate today = LocalDate.now();
		CountDownLatch ready = new CountDownLatch(2);
		CountDownLatch start = new CountDownLatch(1);
		ExecutorService executor = Executors.newFixedThreadPool(2);
		try {
			Future<DailyReportResponse> first = executor.submit(() -> {
				ready.countDown();
				start.await(10, TimeUnit.SECONDS);
				return reportService.submit(worker.getId(), bookingId,
					new DailyReportRequest(today, "并发日报A", null));
			});
			Future<DailyReportResponse> second = executor.submit(() -> {
				ready.countDown();
				start.await(10, TimeUnit.SECONDS);
				return reportService.submit(worker.getId(), bookingId,
					new DailyReportRequest(today, "并发日报B", null));
			});

			assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
			start.countDown();
			List<Integer> revisions = List.of(
				first.get(10, TimeUnit.SECONDS).reportRevision(),
				second.get(10, TimeUnit.SECONDS).reportRevision());

			assertThat(revisions).containsExactlyInAnyOrder(1, 2);
			assertThat(reportService.findByBooking(owner.getId(), bookingId))
				.hasSize(2);
		} finally {
			executor.shutdownNow();
		}
	}

	@Test
	void submitRejectsMoreThanNinePhotos() {
		UUID bookingId = createHiredBooking();
		List<String> photos = java.util.stream.IntStream.range(0, 10)
			.mapToObj(index -> trustedPhotoUrl(index + ".jpg"))
			.toList();

		Throwable error = catchThrowable(() -> reportService.submit(
			worker.getId(), bookingId,
			new DailyReportRequest(LocalDate.now(), "超出数量的日报", photos)));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("DAILY_REPORT_TOO_MANY_PHOTOS");
		});
	}

	@Test
	void submitRejectsUntrustedPhotoOrigin() {
		UUID bookingId = createHiredBooking();

		Throwable error = catchThrowable(() -> reportService.submit(
			worker.getId(), bookingId,
			new DailyReportRequest(LocalDate.now(), "不可信照片", List.of(
				"https://tracker.example/collect/daily-reports/photo.jpg"))));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("INVALID_DAILY_REPORT_PHOTO");
		});
	}

	@Test
	void submitAcceptsPhotoFromConfiguredFullOrigin() {
		UUID bookingId = createHiredBooking();
		DailyReportService productionOriginService = new DailyReportService(
			reportRepository, bookings, businessEventPublisher,
			"http://47.109.0.191:8080",
			"zhidi-uploads-1234567890", "ap-guangzhou");

		DailyReportResponse response = new TransactionTemplate(transactionManager)
			.execute(status -> productionOriginService.submit(
				worker.getId(), bookingId,
				new DailyReportRequest(LocalDate.now(), "正式接口照片",
					List.of("http://47.109.0.191:8080/uploads/daily-reports/photo.jpg"))));

		assertThat(response.photos()).containsExactly(
			"http://47.109.0.191:8080/uploads/daily-reports/photo.jpg");
	}

	@Test
	void submitAcceptsAndroidEmulatorOriginInNonProductionProfile() {
		UUID bookingId = createHiredBooking();
		String photoUrl =
			"http://10.0.2.2:8080/uploads/daily-reports/emulator-photo.jpg";

		DailyReportResponse response = reportService.submit(
			worker.getId(), bookingId,
			new DailyReportRequest(LocalDate.now(), "模拟器施工照片", List.of(photoUrl)));

		assertThat(response.photos()).containsExactly(photoUrl);
	}

	@Test
	void productionOriginDoesNotTrustAndroidEmulatorOrigin() {
		UUID bookingId = createHiredBooking();
		DailyReportService productionOriginService = new DailyReportService(
			reportRepository, bookings, businessEventPublisher,
			"http://47.109.0.191:8080",
			"zhidi-uploads-1234567890", "ap-guangzhou");

		Throwable error = catchThrowable(() ->
			new TransactionTemplate(transactionManager).execute(status ->
				productionOriginService.submit(worker.getId(), bookingId,
					new DailyReportRequest(LocalDate.now(), "生产环境拒绝模拟器来源",
						List.of("http://10.0.2.2:8080/uploads/daily-reports/photo.jpg")))));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("INVALID_DAILY_REPORT_PHOTO");
		});
	}

	@Test
	void submitRejectsConfiguredHostOnUnexpectedPort() {
		UUID bookingId = createHiredBooking();

		Throwable error = catchThrowable(() -> reportService.submit(
			worker.getId(), bookingId,
			new DailyReportRequest(LocalDate.now(), "错误端口照片", List.of(
				"http://127.0.0.1:65535/uploads/daily-reports/photo.jpg"))));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("INVALID_DAILY_REPORT_PHOTO");
		});
	}

	@Test
	void submitRejectsConfiguredHostOnUnexpectedScheme() {
		UUID bookingId = createHiredBooking();

		Throwable error = catchThrowable(() -> reportService.submit(
			worker.getId(), bookingId,
			new DailyReportRequest(LocalDate.now(), "错误协议照片", List.of(
				"https://127.0.0.1:8080/uploads/daily-reports/photo.jpg"))));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("INVALID_DAILY_REPORT_PHOTO");
		});
	}

	@Test
	void submitRejectsInsecureCosOrigin() {
		UUID bookingId = createHiredBooking();

		Throwable error = catchThrowable(() -> reportService.submit(
			worker.getId(), bookingId,
			new DailyReportRequest(LocalDate.now(), "不安全对象存储照片", List.of(
				"http://zhidi-uploads-1234567890.cos.ap-guangzhou.myqcloud.com/"
					+ "daily-reports/photo.jpg"))));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("INVALID_DAILY_REPORT_PHOTO");
		});
	}

	@Test
	void submitRejectsOversizedContent() {
		UUID bookingId = createHiredBooking();

		Throwable error = catchThrowable(() -> reportService.submit(
			worker.getId(), bookingId,
			new DailyReportRequest(LocalDate.now(), "x".repeat(2001), null)));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(400);
			assertThat(ex.code()).isEqualTo("DAILY_REPORT_CONTENT_TOO_LONG");
		});
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

		List<DailyReportResponse> reports = reportService.findByBooking(
			owner.getId(), bookingId);
		assertThat(reports).hasSize(2);
		assertThat(reports.get(0).reportDate()).isEqualTo(today);
		assertThat(reports.get(1).reportDate()).isEqualTo(today.minusDays(1));
	}

	@Test
	void unrelatedUserCannotReadDailyReports() {
		UUID bookingId = createHiredBooking();
		User unrelated = createUser("13800138212", UserRole.OWNER);

		Throwable error = catchThrowable(() ->
			reportService.findByBooking(unrelated.getId(), bookingId));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status()).isEqualTo(org.springframework.http.HttpStatus.NOT_FOUND);
			assertThat(ex.code()).isEqualTo("BOOKING_NOT_FOUND");
		});
	}

	private UUID createHiredBooking() {
		UUID requestId = serviceRequests.saveAndFlush(ServiceRequest.create(
			owner.getId(), "木工", "杭州", "余杭区", "测试木工")).getId();

		Booking booking = bookings.saveAndFlush(Booking.createCandidate(
			serviceRequests.findById(requestId).orElseThrow(),
			owner.getId(), "张业主", owner.getPhone(),
			worker.getId(), "李师傅"));
		ReflectionTestUtils.setField(booking, "status", BookingStatus.HIRED);
		booking = bookings.saveAndFlush(booking);
		return booking.getId();
	}

	private String trustedPhotoUrl(String fileName) {
		return "http://127.0.0.1:8080/uploads/daily-reports/2026/08/09/" + fileName;
	}

	private User createUser(String phone, UserRole role) {
		User user = User.create(phone);
		user.grantRole(role);
		return users.saveAndFlush(user);
	}
}
