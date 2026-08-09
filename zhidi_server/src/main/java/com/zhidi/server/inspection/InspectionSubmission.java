package com.zhidi.server.inspection;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "inspection_submissions")
public class InspectionSubmission extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "node_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID nodeId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@Column(columnDefinition = "TEXT")
	private String note;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "JSON")
	private List<String> photos;

	@Column(name = "submission_version", nullable = false)
	private int submissionVersion;

	protected InspectionSubmission() {
	}

	private InspectionSubmission(UUID nodeId, UUID workerUserId, String note,
			List<String> photos, int submissionVersion) {
		this.nodeId = Objects.requireNonNull(nodeId);
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.note = note;
		this.photos = photos == null || photos.isEmpty() ? null : List.copyOf(photos);
		this.submissionVersion = submissionVersion;
	}

	public static InspectionSubmission create(UUID nodeId, UUID workerUserId,
			String note, List<String> photos, int submissionVersion) {
		return new InspectionSubmission(nodeId, workerUserId, note, photos,
			submissionVersion);
	}

	public UUID getNodeId() { return nodeId; }
	public UUID getWorkerUserId() { return workerUserId; }
	public String getNote() { return note; }
	public List<String> getPhotos() {
		return photos == null ? Collections.emptyList()
			: Collections.unmodifiableList(photos);
	}
	public int getSubmissionVersion() { return submissionVersion; }
}
