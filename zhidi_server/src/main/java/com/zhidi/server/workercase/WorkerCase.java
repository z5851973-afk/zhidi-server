package com.zhidi.server.workercase;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "worker_cases")
public class WorkerCase extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@Column(nullable = false, length = 120)
	private String title;

	@Column(nullable = false, length = 1000)
	private String description;

	@Column(name = "service_city", nullable = false, length = 80)
	private String serviceCity;

	@Column(name = "completion_year", nullable = false)
	private int completionYear;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(name = "image_urls", nullable = false, columnDefinition = "JSON")
	private List<String> imageUrls;

	protected WorkerCase() {
	}

	private WorkerCase(UUID workerUserId, WorkerCaseRequest request) {
		this.workerUserId = Objects.requireNonNull(workerUserId);
		apply(request);
	}

	public static WorkerCase create(UUID workerUserId, WorkerCaseRequest request) {
		return new WorkerCase(workerUserId, request);
	}

	public void update(WorkerCaseRequest request) {
		apply(request);
	}

	private void apply(WorkerCaseRequest request) {
		Objects.requireNonNull(request);
		this.title = request.title().trim();
		this.description = request.description().trim();
		this.serviceCity = request.serviceCity().trim();
		this.completionYear = request.completionYear();
		this.imageUrls = List.copyOf(request.imageUrls());
	}

	public UUID getWorkerUserId() {
		return workerUserId;
	}

	public String getTitle() {
		return title;
	}

	public String getDescription() {
		return description;
	}

	public String getServiceCity() {
		return serviceCity;
	}

	public int getCompletionYear() {
		return completionYear;
	}

	public List<String> getImageUrls() {
		return List.copyOf(imageUrls);
	}
}
