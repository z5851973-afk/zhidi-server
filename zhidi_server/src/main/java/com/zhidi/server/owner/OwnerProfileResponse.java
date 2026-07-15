package com.zhidi.server.owner;

import java.math.BigDecimal;
import java.util.UUID;

public record OwnerProfileResponse(
	UUID userId,
	String phone,
	String name,
	String city,
	String decorationType,
	String address,
	BigDecimal area,
	boolean profileComplete
) {
}
