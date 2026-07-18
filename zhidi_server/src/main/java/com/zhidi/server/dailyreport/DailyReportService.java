package com.zhidi.server.dailyreport;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DailyReportService {

	private final DailyReportRepository reportRepository;
	private final BookingRepository bookingRepository;

	public DailyReportService(DailyReportRepository reportRepository,
			BookingRepository bookingRepository) {
		this.reportRepository = reportRepository;
		this.bookingRepository = bookingRepository;
	}

	@Transactional
	public DailyReportResponse submit(UUID workerUserId, UUID bookingId,
			DailyReportRequest request) {
		Booking booking = bookingRepository.findByIdAndWorkerUserId(bookingId, workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));

		if (booking.getStatus() != BookingStatus.HIRED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有已选定(HIRED)的预约才能提交日报");
		}

		Optional<DailyReport> existing = reportRepository
			.findByBookingIdAndReportDate(bookingId, request.reportDate());

		if (existing.isPresent()) {
			DailyReport report = existing.get();
			report.updateContent(request.content(), request.photos());
			return DailyReportResponse.from(reportRepository.save(report));
		}

		DailyReport report = DailyReport.create(bookingId, workerUserId,
			request.reportDate(), request.content(), request.photos());
		return DailyReportResponse.from(reportRepository.save(report));
	}

	@Transactional(readOnly = true)
	public List<DailyReportResponse> findByBooking(UUID bookingId) {
		return reportRepository.findByBookingIdOrderByReportDateDesc(bookingId)
				.stream()
				.map(DailyReportResponse::from)
				.toList();
	}
}
