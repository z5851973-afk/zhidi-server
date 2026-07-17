package com.zhidi.server.servicerequest;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "service_requests")
public class ServiceRequest extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "owner_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID ownerUserId;

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
	private ServiceRequestStatus status;

	protected ServiceRequest() {
	}

	private ServiceRequest(UUID ownerUserId, String trade, String serviceCity,
			String serviceAddress, String remark) {
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		this.trade = Objects.requireNonNull(trade);
		this.serviceCity = Objects.requireNonNull(serviceCity);
		this.serviceAddress = serviceAddress;
		this.remark = remark;
		this.status = ServiceRequestStatus.OPEN;
	}

	public static ServiceRequest create(UUID ownerUserId, String trade,
			String serviceCity, String serviceAddress, String remark) {
		return new ServiceRequest(ownerUserId, trade, serviceCity, serviceAddress, remark);
	}

	public UUID getOwnerUserId() {
		return ownerUserId;
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

	public ServiceRequestStatus getStatus() {
		return status;
	}

	void setStatus(ServiceRequestStatus status) {
		this.status = Objects.requireNonNull(status);
	}

	public void selectWorker() {
		this.status = ServiceRequestStatus.WORKER_SELECTED;
	}

	public void reopen() {
		this.status = ServiceRequestStatus.OPEN;
	}

	public void cancel() {
		this.status = ServiceRequestStatus.CANCELLED;
	}
}
