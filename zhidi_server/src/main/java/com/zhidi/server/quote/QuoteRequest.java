package com.zhidi.server.quote;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;

public record QuoteRequest(
	@NotEmpty List<@NotNull QuoteItem> items
) {
}
