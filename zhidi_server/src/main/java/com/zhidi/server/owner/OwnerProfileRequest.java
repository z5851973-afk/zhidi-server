package com.zhidi.server.owner;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record OwnerProfileRequest(
	@Size(max = 80) String name,
	@Size(max = 80) String city,
	@Size(max = 40) String decorationType,
	@Size(max = 255) String address,
	@DecimalMin("1.00")
	@DecimalMax("99999.99")
	@Digits(integer = 5, fraction = 2)
	BigDecimal area,
	@Size(max = 500)
	@Pattern(regexp = "^$|^/uploads/owner-avatar/[A-Za-z0-9_./-]+\\.(?i:jpg|jpeg|png|webp)$")
	String avatarUrl,
	@Size(max = 20)
	@Pattern(regexp = "^$|^(MALE|FEMALE|UNDISCLOSED)$")
	String gender
) {
	public OwnerProfileRequest(String name, String city, String decorationType,
			String address, BigDecimal area) {
		this(name, city, decorationType, address, area, null, null);
	}
}
