package com.zhidi.server.payment;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "after_sale_events")
public class AfterSaleEvent extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "after_sale_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID afterSaleId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "actor_user_id", updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID actorUserId;

	@Enumerated(EnumType.STRING)
	@Column(name = "actor_role", nullable = false, updatable = false, length = 24)
	private AfterSaleActorRole actorRole;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, updatable = false, length = 40)
	private AfterSaleEventType type;

	@Column(columnDefinition = "TEXT", updatable = false)
	private String content;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(name = "evidence_urls", nullable = false, updatable = false,
		columnDefinition = "JSON")
	private List<String> evidenceUrls;

	@Column(name = "idempotency_key", nullable = false, updatable = false,
		length = 128)
	private String idempotencyKey;

	protected AfterSaleEvent() {
	}

	private AfterSaleEvent(UUID afterSaleId, UUID actorUserId,
			AfterSaleActorRole actorRole, AfterSaleEventType type, String content,
			List<String> evidenceUrls, String idempotencyKey) {
		this.afterSaleId = Objects.requireNonNull(afterSaleId);
		this.actorUserId = actorUserId;
		this.actorRole = Objects.requireNonNull(actorRole);
		this.type = Objects.requireNonNull(type);
		this.content = normalize(content);
		this.evidenceUrls = evidenceUrls == null ? List.of() : List.copyOf(evidenceUrls);
		this.idempotencyKey = requireText(idempotencyKey, "idempotencyKey");
	}

	public static AfterSaleEvent create(UUID afterSaleId, UUID actorUserId,
			AfterSaleActorRole actorRole, AfterSaleEventType type, String content,
			List<String> evidenceUrls, String idempotencyKey) {
		return new AfterSaleEvent(afterSaleId, actorUserId, actorRole, type,
			content, evidenceUrls, idempotencyKey);
	}

	public UUID getAfterSaleId() { return afterSaleId; }
	public UUID getActorUserId() { return actorUserId; }
	public AfterSaleActorRole getActorRole() { return actorRole; }
	public AfterSaleEventType getType() { return type; }
	public String getContent() { return content; }
	public List<String> getEvidenceUrls() {
		return evidenceUrls == null ? List.of() : List.copyOf(evidenceUrls);
	}
	public String getIdempotencyKey() { return idempotencyKey; }

	private static String normalize(String value) {
		return value == null || value.isBlank() ? null : value.trim();
	}

	private static String requireText(String value, String field) {
		if (value == null || value.isBlank()) {
			throw new IllegalArgumentException(field + " must not be blank");
		}
		return value.trim();
	}
}
