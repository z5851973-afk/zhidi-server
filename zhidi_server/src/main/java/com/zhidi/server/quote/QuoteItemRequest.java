package com.zhidi.server.quote;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record QuoteItemRequest(
	@NotBlank String name,
	@NotNull
	@DecimalMin(value = "0.01", message = "数量必须大于 0")
	@DecimalMax(value = "100000", message = "数量超过允许上限")
	BigDecimal quantity,
	BigDecimal unitPrice
) {
}
