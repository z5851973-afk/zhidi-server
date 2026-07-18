package com.zhidi.server.dailyreport;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record DailyReportResponse(
		UUID id,
		UUID bookingId,
		UUID workerUserId,
		LocalDate reportDate,
		String content,
		List<String> photos,
		Instant createdAt,
		Instant updatedAt
) {
	public static DailyReportResponse from(DailyReport report) {
		return new DailyReportResponse(
				report.getId(),
				report.getBookingId(),
				report.getWorkerUserId(),
				report.getReportDate(),
				report.getContent(),
				report.getPhotos(),
				report.getCreatedAt(),
				report.getUpdatedAt()
		);
	}
}
