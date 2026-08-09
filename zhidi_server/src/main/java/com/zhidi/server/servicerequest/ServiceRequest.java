package com.zhidi.server.servicerequest;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
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

	@Column(name = "area_sqm", precision = 8, scale = 2)
	private BigDecimal areaSqm;

	@Column(name = "bedroom_count")
	private Short bedroomCount;

	@Column(name = "living_room_count")
	private Short livingRoomCount;

	@Column(name = "kitchen_count")
	private Short kitchenCount;

	@Column(name = "bathroom_count")
	private Short bathroomCount;

	@Column(length = 500)
	private String remark;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private ServiceRequestStatus status;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "reopened_request_id", columnDefinition = "BINARY(16)")
	private UUID reopenedRequestId;

	protected ServiceRequest() {
	}

	private ServiceRequest(UUID ownerUserId, String trade, String serviceCity,
			String serviceAddress, BigDecimal areaSqm, Short bedroomCount,
			Short livingRoomCount, Short kitchenCount, Short bathroomCount,
			String remark) {
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		this.trade = Objects.requireNonNull(trade);
		this.serviceCity = Objects.requireNonNull(serviceCity);
		this.serviceAddress = serviceAddress;
		this.areaSqm = areaSqm;
		this.bedroomCount = bedroomCount;
		this.livingRoomCount = livingRoomCount;
		this.kitchenCount = kitchenCount;
		this.bathroomCount = bathroomCount;
		this.remark = remark;
		this.status = ServiceRequestStatus.OPEN;
	}

	public static ServiceRequest create(UUID ownerUserId, String trade,
			String serviceCity, String serviceAddress, String remark) {
		return new ServiceRequest(ownerUserId, trade, serviceCity, serviceAddress,
			null, null, null, null, null, remark);
	}

	public static ServiceRequest create(UUID ownerUserId, String trade,
			String serviceCity, String serviceAddress, BigDecimal areaSqm,
			Short bedroomCount, Short livingRoomCount, Short kitchenCount,
			Short bathroomCount, String remark) {
		validateHouseInfo(areaSqm, bedroomCount, livingRoomCount, kitchenCount,
			bathroomCount);
		return new ServiceRequest(ownerUserId, trade, serviceCity, serviceAddress,
			areaSqm, bedroomCount, livingRoomCount, kitchenCount, bathroomCount,
			remark);
	}

	public static ServiceRequest recreate(UUID ownerUserId, String trade,
			String serviceCity, String serviceAddress, BigDecimal areaSqm,
			Short bedroomCount, Short livingRoomCount, Short kitchenCount,
			Short bathroomCount, String remark) {
		if (areaSqm == null && bedroomCount == null && livingRoomCount == null
				&& kitchenCount == null && bathroomCount == null) {
			return create(ownerUserId, trade, serviceCity, serviceAddress, remark);
		}
		return create(ownerUserId, trade, serviceCity, serviceAddress, areaSqm,
			bedroomCount, livingRoomCount, kitchenCount, bathroomCount, remark);
	}

	private static void validateHouseInfo(BigDecimal areaSqm, Short bedroomCount,
			Short livingRoomCount, Short kitchenCount, Short bathroomCount) {
		Objects.requireNonNull(areaSqm, "areaSqm");
		Objects.requireNonNull(bedroomCount, "bedroomCount");
		Objects.requireNonNull(livingRoomCount, "livingRoomCount");
		Objects.requireNonNull(kitchenCount, "kitchenCount");
		Objects.requireNonNull(bathroomCount, "bathroomCount");
		if (areaSqm.compareTo(BigDecimal.ONE) < 0
				|| areaSqm.compareTo(new BigDecimal("9999")) > 0
				|| areaSqm.scale() > 2
				|| bedroomCount < 1 || bedroomCount > 20
				|| livingRoomCount < 0 || livingRoomCount > 10
				|| kitchenCount < 0 || kitchenCount > 10
				|| bathroomCount < 1 || bathroomCount > 20) {
			throw new IllegalArgumentException("房屋信息超出允许范围");
		}
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

	public BigDecimal getAreaSqm() {
		return areaSqm;
	}

	public Short getBedroomCount() {
		return bedroomCount;
	}

	public Short getLivingRoomCount() {
		return livingRoomCount;
	}

	public Short getKitchenCount() {
		return kitchenCount;
	}

	public Short getBathroomCount() {
		return bathroomCount;
	}

	public String getRemark() {
		return remark;
	}

	public ServiceRequestStatus getStatus() {
		return status;
	}

	public UUID getReopenedRequestId() {
		return reopenedRequestId;
	}

	void setStatus(ServiceRequestStatus status) {
		this.status = Objects.requireNonNull(status);
	}

	public void syncActiveCandidateCount(long activeCandidateCount) {
		if (status == ServiceRequestStatus.ASSIGNED
				|| status == ServiceRequestStatus.WORKER_SELECTED
				|| status == ServiceRequestStatus.CANCELLED) {
			return;
		}
		this.status = activeCandidateCount >= 2
			? ServiceRequestStatus.COMPARING
			: ServiceRequestStatus.OPEN;
	}

	public void selectWorker() {
		this.status = ServiceRequestStatus.WORKER_SELECTED;
	}

	public void markAssigned() {
		this.status = ServiceRequestStatus.ASSIGNED;
	}

	public void reopen() {
		this.status = ServiceRequestStatus.OPEN;
	}

	public void cancel() {
		this.status = ServiceRequestStatus.CANCELLED;
	}

	public void markReopenedAs(UUID successorRequestId) {
		if (status != ServiceRequestStatus.CANCELLED) {
			throw new IllegalStateException("only cancelled requests can be reopened");
		}
		UUID successor = Objects.requireNonNull(successorRequestId);
		if (reopenedRequestId != null && !reopenedRequestId.equals(successor)) {
			throw new IllegalStateException("request already has a reopen successor");
		}
		this.reopenedRequestId = successor;
	}
}
