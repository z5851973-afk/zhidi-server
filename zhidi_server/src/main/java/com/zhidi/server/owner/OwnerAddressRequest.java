package com.zhidi.server.owner;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record OwnerAddressRequest(
	@NotBlank @Size(max = 80) String recipient,
	@NotBlank @Pattern(regexp = "^1[3-9]\\d{9}$") String phone,
	@NotBlank @Size(max = 80) String province,
	@NotBlank @Size(max = 80) String city,
	@NotBlank @Size(max = 80) String district,
	@NotBlank @Size(max = 255) String detail,
	boolean isDefault
) {
}
