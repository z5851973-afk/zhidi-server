package com.zhidi.server.owner;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "owner_addresses")
public class OwnerAddress extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "owner_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID ownerUserId;

	@Column(nullable = false, length = 80)
	private String recipient;

	@Column(nullable = false, length = 20)
	private String phone;

	@Column(nullable = false, length = 80)
	private String province;

	@Column(nullable = false, length = 80)
	private String city;

	@Column(nullable = false, length = 80)
	private String district;

	@Column(nullable = false, length = 255)
	private String detail;

	@Column(name = "is_default", nullable = false)
	private boolean defaultAddress;

	protected OwnerAddress() {
	}

	private OwnerAddress(UUID ownerUserId, OwnerAddressRequest request,
			boolean defaultAddress) {
		this.ownerUserId = Objects.requireNonNull(ownerUserId);
		updateDetails(request);
		this.defaultAddress = defaultAddress;
	}

	public static OwnerAddress create(UUID ownerUserId, OwnerAddressRequest request,
			boolean defaultAddress) {
		return new OwnerAddress(ownerUserId, request, defaultAddress);
	}

	public UUID getOwnerUserId() {
		return ownerUserId;
	}

	public String getRecipient() {
		return recipient;
	}

	public String getPhone() {
		return phone;
	}

	public String getProvince() {
		return province;
	}

	public String getCity() {
		return city;
	}

	public String getDistrict() {
		return district;
	}

	public String getDetail() {
		return detail;
	}

	public boolean isDefaultAddress() {
		return defaultAddress;
	}

	public void updateDetails(OwnerAddressRequest request) {
		this.recipient = normalize(request.recipient());
		this.phone = normalize(request.phone());
		this.province = normalize(request.province());
		this.city = normalize(request.city());
		this.district = normalize(request.district());
		this.detail = normalize(request.detail());
	}

	public void markDefault(boolean value) {
		this.defaultAddress = value;
	}

	private String normalize(String value) {
		return Objects.requireNonNull(value).trim();
	}
}
