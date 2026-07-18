package com.zhidi.server.inspection;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "inspection_records")
public class InspectionRecord extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "node_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID nodeId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "inspector_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID inspectorUserId;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 16)
	private InspectionResult result;

	@Column(columnDefinition = "TEXT")
	private String comment;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(columnDefinition = "JSON")
	private List<String> photos;

	@Column(nullable = false)
	private int version;

	protected InspectionRecord() {
	}

	private InspectionRecord(UUID nodeId, UUID inspectorUserId,
			InspectionResult result, String comment, List<String> photos,
			int version) {
		this.nodeId = Objects.requireNonNull(nodeId);
		this.inspectorUserId = Objects.requireNonNull(inspectorUserId);
		this.result = Objects.requireNonNull(result);
		this.comment = comment;
		this.photos = (photos == null || photos.isEmpty()) ? null : List.copyOf(photos);
		this.version = version;
	}

	public static InspectionRecord create(UUID nodeId, UUID inspectorUserId,
			InspectionResult result, String comment, List<String> photos,
			int version) {
		return new InspectionRecord(nodeId, inspectorUserId, result, comment,
			photos, version);
	}

	public UUID getNodeId() { return nodeId; }
	public UUID getInspectorUserId() { return inspectorUserId; }
	public InspectionResult getResult() { return result; }
	public String getComment() { return comment; }
	public List<String> getPhotos() {
		return photos != null ? Collections.unmodifiableList(photos) : Collections.emptyList();
	}
	public int getVersion() { return version; }
}
