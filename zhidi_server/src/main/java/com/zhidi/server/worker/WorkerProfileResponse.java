package com.zhidi.server.worker;

import java.math.BigDecimal;
import java.util.UUID;

public record WorkerProfileResponse(
	UUID userId,
	String phone,
	String name,
	String serviceCity,
	String primaryTrade,
	Integer experienceYears,
	BigDecimal dailyRate,
	String bio,
	boolean profileComplete
) {
}
