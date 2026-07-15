package com.zhidi.server.worker;

import java.math.BigDecimal;
import java.util.UUID;

public record WorkerDirectoryResponse(
	UUID userId,
	String name,
	String serviceCity,
	String primaryTrade,
	Integer experienceYears,
	BigDecimal dailyRate,
	String bio
) {
}
