package com.zhidi.server.booking;

import com.zhidi.server.common.persistence.BaseEntity;
import com.zhidi.server.servicerequest.ServiceRequest;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "bookings")
public class Booking extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "service_request_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID serviceRequestId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "owner_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID ownerUserId;

	@Column(name = "owner_name", nullable = false, length = 80, updatable = false)
	private String ownerName;

	@Column(name = "owner_phone", nullable = false, length = 32, updatable = false)
	private String ownerPhone;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@Column(name = "worker_name", nullable = false, length = 80)
	private String workerName;

	@Column(nullable = false, length = 40)
	private String trade;

	@Column(name = "service_city", nullable = false, length = 80)
	private String serviceCity;

	@Column(name = "service_address", length = 200)
	private String serviceAddress;

	@Column(length = 500)
	private String remark;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private BookingStatus status;

	@Column(name = "cancelled_by", length = 16)
	private String cancelledBy;

	@Column(name = "cancel_reason", length = 300)
	private String cancelReason;

	@Column(name = "cancelled_at")
	private Instant cancelledAt;

	protected Booking() {
	}

	private Booking(UUID serviceRequestId, UUID ownerUserId, String ownerName,
			String ownerPhone, UUID workerUserId, String workerName,
			String trade, String serviceCity, String serviceAddress, String remark) {
		this.serviceRequestId = Objects.requireNonNull(serviceRequestId);
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		this.ownerName = Objects.requireNonNull(ownerName);
		this.ownerPhone = Objects.requireNonNull(ownerPhone);
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.workerName = Objects.requireNonNull(workerName);
		this.trade = Objects.requireNonNull(trade);
		this.serviceCity = Objects.requireNonNull(serviceCity);
		this.serviceAddress = serviceAddress;
		this.remark = remark;
		this.status = BookingStatus.PENDING;
	}

	public static Booking create(UUID ownerUserId, String ownerName, String ownerPhone,
			UUID workerUserId, String workerName,
			String trade, String serviceCity, String serviceAddress, String remark) {
		return new Booking(null, ownerUserId, ownerName, ownerPhone, workerUserId, workerName,
			trade, serviceCity, serviceAddress, remark);
	}

	public static Booking createCandidate(ServiceRequest request, UUID ownerUserId,
			String ownerName, String ownerPhone, UUID workerUserId, String workerName) {
		return new Booking(request.getId(), ownerUserId, ownerName, ownerPhone,
			workerUserId, workerName,
			request.getTrade(), request.getServiceCity(),
			request.getServiceAddress(), request.getRemark());
	}

	public UUID getServiceRequestId() {
		return serviceRequestId;
	}

	public UUID getOwnerUserId() {
		return ownerUserId;
	}

	public UUID getWorkerUserId() {
		return workerUserId;
	}

	public String getOwnerName() {
		return ownerName;
	}

	public String getOwnerPhone() {
		return ownerPhone;
	}

	public String getWorkerName() {
		return workerName;
	}

	public String getTrade() {
		return trade;
	}

	public String getServiceCity() {
		return serviceCity;
	}

	public String getServiceAddress() {
		return serviceAddress;
	}

	public String getRemark() {
		return remark;
	}

	public BookingStatus getStatus() {
		return status;
	}

	public String getCancelledBy() {
		return cancelledBy;
	}

	public String getCancelReason() {
		return cancelReason;
	}

	public Instant getCancelledAt() {
		return cancelledAt;
	}

	public void accept() {
		this.status = BookingStatus.ACCEPTED;
	}

	public void reject() {
		this.status = BookingStatus.REJECTED;
	}

	public void notSelect() {
		this.status = BookingStatus.NOT_SELECTED;
	}

	public boolean canCancelBeforeOnSite() {
		return switch (status) {
			case PENDING, ACCEPTED, VISIT_PROPOSED,
				 VISIT_SCHEDULED, ARRIVAL_PENDING -> true;
			case ON_SITE, QUOTE_PENDING, READY_TO_START,
				 REJECTED, CANCELLED, NOT_SELECTED -> false;
		};
	}

	public void cancel(BookingCancellationActor actor, String cancelReason,
			Instant cancelledAt) {
		if (!canCancelBeforeOnSite()) {
			throw new IllegalStateException("工人确认上门后不能普通取消");
		}
		this.status = BookingStatus.CANCELLED;
		this.cancelledBy = Objects.requireNonNull(actor).name();
		this.cancelReason = Objects.requireNonNull(cancelReason).trim();
		this.cancelledAt = Objects.requireNonNull(cancelledAt);
	}
}
