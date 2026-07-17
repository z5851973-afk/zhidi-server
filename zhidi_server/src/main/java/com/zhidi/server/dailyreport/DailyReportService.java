package com.zhidi.server.dailyreport;

import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DailyReportService {

	private final DailyReportRepository reportRepository;

	public DailyReportService(DailyReportRepository reportRepository) {
		this.reportRepository = reportRepository;
	}

	@Transactional
	public DailyReportResponse submit(UUID bookingId, UUID workerUserId, DailyReportRequest request) {
		DailyReport report = DailyReport.create(
				bookingId,
				workerUserId,
				request.title(),
				request.content(),
				request.imageUrls());
		return DailyReportResponse.from(reportRepository.save(report));
	}

	@Transactional(readOnly = true)
	public List<DailyReportResponse> findByBooking(UUID bookingId) {
		return reportRepository.findByBookingIdOrderByCreatedAtDesc(bookingId)
				.stream()
				.map(DailyReportResponse::from)
				.toList();
	}

	@Transactional(readOnly = true)
	public List<DailyReportResponse> findByWorker(UUID workerUserId) {
		return reportRepository.findByWorkerUserIdOrderByCreatedAtDesc(workerUserId)
				.stream()
				.map(DailyReportResponse::from)
				.toList();
	}
}
