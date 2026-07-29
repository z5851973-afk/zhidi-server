package com.zhidi.server.audit;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "operation_logs")
public class OperationLog {

	@Id
	@GeneratedValue
	@UuidGenerator
	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(nullable = false, updatable = false, columnDefinition = "BINARY(16)")
	private UUID id;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "actor_user_id", columnDefinition = "BINARY(16)")
	private UUID actorUserId;

	@Column(nullable = false, length = 100)
	private String action;

	@Column(name = "target_type", length = 80)
	private String targetType;

	@Column(name = "target_id", length = 80)
	private String targetId;

	@Column(nullable = false, length = 32)
	private String result;

	@Column(name = "trace_id", nullable = false, length = 64)
	private String traceId;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(name = "detail_json", columnDefinition = "JSON")
	private String detailJson;

	@Column(name = "created_at", nullable = false, updatable = false)
	private Instant createdAt;

	protected OperationLog() {
	}

	public static OperationLog success(UUID actorUserId, String action,
			String targetType, String targetId, String traceId, String detailJson) {
		OperationLog log = new OperationLog();
		log.actorUserId = actorUserId;
		log.action = action;
		log.targetType = targetType;
		log.targetId = targetId;
		log.result = "SUCCESS";
		log.traceId = traceId == null || traceId.isBlank() ? "unknown" : traceId;
		log.detailJson = detailJson;
		return log;
	}

	@PrePersist
	void prePersist() {
		this.createdAt = Instant.now();
	}

	public UUID getActorUserId() {
		return actorUserId;
	}

	public String getAction() {
		return action;
	}

	public String getTargetType() {
		return targetType;
	}

	public String getTargetId() {
		return targetId;
	}

	public String getResult() {
		return result;
	}

	public String getTraceId() {
		return traceId;
	}

	public String getDetailJson() {
		return detailJson;
	}
}
