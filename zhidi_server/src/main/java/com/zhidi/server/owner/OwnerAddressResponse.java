package com.zhidi.server.owner;

import java.time.Instant;
import java.util.UUID;

public record OwnerAddressResponse(
	UUID id,
	String recipient,
	String phone,
	String province,
	String city,
	String district,
	String detail,
	boolean isDefault,
	Instant createdAt,
	Instant updatedAt
) {
	public static OwnerAddressResponse from(OwnerAddress address) {
		return new OwnerAddressResponse(address.getId(), address.getRecipient(),
			address.getPhone(), address.getProvince(), address.getCity(),
			address.getDistrict(), address.getDetail(), address.isDefaultAddress(),
			address.getCreatedAt(), address.getUpdatedAt());
	}
}
