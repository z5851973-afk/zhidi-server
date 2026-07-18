package com.zhidi.server.dailyreport;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "daily_reports")
public class DailyReport extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@Column(name = "report_date", nullable = false)
	private LocalDate reportDate;

	@Column(nullable = false, columnDefinition = "TEXT")
	private String content;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "JSON")
	private List<String> photos;

	protected DailyReport() {
	}

	private DailyReport(UUID bookingId, UUID workerUserId, LocalDate reportDate,
			String content, List<String> photos) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.reportDate = Objects.requireNonNull(reportDate);
		this.content = Objects.requireNonNull(content);
		this.photos = (photos == null || photos.isEmpty()) ? null : List.copyOf(photos);
	}

	public static DailyReport create(UUID bookingId, UUID workerUserId,
			LocalDate reportDate, String content, List<String> photos) {
		return new DailyReport(bookingId, workerUserId, reportDate, content, photos);
	}

	public UUID getBookingId() { return bookingId; }
	public UUID getWorkerUserId() { return workerUserId; }
	public LocalDate getReportDate() { return reportDate; }
	public String getContent() { return content; }
	public List<String> getPhotos() {
		return photos != null ? Collections.unmodifiableList(photos) : Collections.emptyList();
	}

	public void updateContent(String content, List<String> photos) {
		this.content = Objects.requireNonNull(content);
		this.photos = (photos == null || photos.isEmpty()) ? null : List.copyOf(photos);
	}
}
