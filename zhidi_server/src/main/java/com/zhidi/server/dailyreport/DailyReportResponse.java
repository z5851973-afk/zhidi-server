package com.zhidi.server.dailyreport;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record DailyReportResponse(
		UUID id,
		UUID bookingId,
		UUID workerUserId,
		String title,
		String content,
		List<String> imageUrls,
		Instant createdAt
) {
	public static DailyReportResponse from(DailyReport report) {
		return new DailyReportResponse(
				report.getId(),
				report.getBookingId(),
				report.getWorkerUserId(),
				report.getTitle(),
				report.getContent(),
				report.getImageUrls(),
				report.getCreatedAt()
		);
	}
}
