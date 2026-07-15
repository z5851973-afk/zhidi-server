package com.zhidi.server.worker;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record WorkerProfileRequest(
	@Size(max = 80) String name,
	@Size(max = 80) String serviceCity,
	@Size(max = 40) String primaryTrade,
	@Min(0) @Max(60) Integer experienceYears,
	@DecimalMin("1.00")
	@DecimalMax("99999.99")
	@Digits(integer = 5, fraction = 2)
	BigDecimal dailyRate,
	@Size(max = 500) String bio
) {
}
