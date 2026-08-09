package com.zhidi.server.servicerequest;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record ServiceRequestCreateRequest(
	@NotBlank @Size(max = 40) String trade,
	@NotBlank @Size(max = 80) String serviceCity,
	@Size(max = 200) String serviceAddress,
	@NotNull @DecimalMin("1.00") @DecimalMax("9999.00")
	@Digits(integer = 4, fraction = 2) BigDecimal areaSqm,
	@NotNull @Min(1) @Max(20) Short bedroomCount,
	@NotNull @Min(0) @Max(10) Short livingRoomCount,
	@NotNull @Min(0) @Max(10) Short kitchenCount,
	@NotNull @Min(1) @Max(20) Short bathroomCount,
	@Size(max = 500) String remark
) {
}
