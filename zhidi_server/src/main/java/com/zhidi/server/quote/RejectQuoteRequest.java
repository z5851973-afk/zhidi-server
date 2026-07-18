package com.zhidi.server.quote;

import jakarta.validation.constraints.NotBlank;

public record RejectQuoteRequest(
	@NotBlank String reason
) {
}
