package com.zhidi.server.quote;

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
@Table(name = "quotes")
public class Quote extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "booking_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID bookingId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@JdbcTypeCode(SqlTypes.JSON)
	@Column(nullable = false, columnDefinition = "JSON")
	private List<QuoteItem> items;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private QuoteStatus status;

	protected Quote() {
	}

	private Quote(UUID bookingId, UUID workerUserId, List<QuoteItem> items) {
		this.bookingId = Objects.requireNonNull(bookingId);
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.items = List.copyOf(items);
		this.status = QuoteStatus.SUBMITTED;
	}

	public static Quote create(UUID bookingId, UUID workerUserId,
			List<QuoteItem> items) {
		return new Quote(bookingId, workerUserId, items);
	}

	public UUID getBookingId() {
		return bookingId;
	}

	public UUID getWorkerUserId() {
		return workerUserId;
	}

	public List<QuoteItem> getItems() {
		return items;
	}

	public QuoteStatus getStatus() {
		return status;
	}

	public void accept() {
		this.status = QuoteStatus.ACCEPTED;
	}

	public void reject() {
		this.status = QuoteStatus.REJECTED;
	}
}
