package com.zhidi.server.quote;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record QuoteItemRequest(
	@NotBlank String name,
	@NotNull BigDecimal quantity,
	BigDecimal unitPrice
) {
}
