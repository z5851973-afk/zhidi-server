package com.zhidi.server.inspection;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "inspection_evidence_assets")
public class InspectionEvidenceAsset extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "node_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID nodeId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "uploader_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID uploaderUserId;

	@Column(name = "public_url", nullable = false, updatable = false, length = 700)
	private String publicUrl;

	@Column(name = "object_key", nullable = false, updatable = false, length = 512)
	private String objectKey;

	protected InspectionEvidenceAsset() {}

	private InspectionEvidenceAsset(UUID bookingId, UUID nodeId,
			UUID uploaderUserId, String publicUrl, String objectKey) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.nodeId = Objects.requireNonNull(nodeId);
		this.uploaderUserId = Objects.requireNonNull(uploaderUserId);
		this.publicUrl = Objects.requireNonNull(publicUrl);
		this.objectKey = Objects.requireNonNull(objectKey);
	}

	public static InspectionEvidenceAsset create(UUID bookingId, UUID nodeId,
			UUID uploaderUserId, String publicUrl, String objectKey) {
		return new InspectionEvidenceAsset(bookingId, nodeId, uploaderUserId,
			publicUrl, objectKey);
	}

	public UUID getBookingId() { return bookingId; }
	public UUID getNodeId() { return nodeId; }
	public UUID getUploaderUserId() { return uploaderUserId; }
	public String getPublicUrl() { return publicUrl; }
	public String getObjectKey() { return objectKey; }
}
