package com.zhidi.server.dailyreport;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.util.ArrayList;
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

	@Column(nullable = false, length = 200)
	private String title;

	@Column(nullable = false, length = 2000)
	private String content;

	@Column(name = "image_urls", columnDefinition = "TEXT")
	private String imageUrls;

	protected DailyReport() {
	}

	private DailyReport(UUID bookingId, UUID workerUserId, String title, String content,
			List<String> imageUrls) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.title = Objects.requireNonNull(title);
		this.content = Objects.requireNonNull(content);
		this.imageUrls = imageUrls.isEmpty() ? null : String.join(",", imageUrls);
	}

	public static DailyReport create(UUID bookingId, UUID workerUserId, String title,
			String content, List<String> imageUrls) {
		List<String> safe = imageUrls != null ? List.copyOf(imageUrls) : Collections.emptyList();
		return new DailyReport(bookingId, workerUserId, title, content, safe);
	}

	public UUID getBookingId() {
		return bookingId;
	}

	public UUID getWorkerUserId() {
		return workerUserId;
	}

	public String getTitle() {
		return title;
	}

	public String getContent() {
		return content;
	}

	public List<String> getImageUrls() {
		if (imageUrls == null || imageUrls.isBlank()) {
			return Collections.emptyList();
		}
		List<String> result = new ArrayList<>();
		for (String url : imageUrls.split(",")) {
			String trimmed = url.trim();
			if (!trimmed.isEmpty()) {
				result.add(trimmed);
			}
		}
		return Collections.unmodifiableList(result);
	}
}
