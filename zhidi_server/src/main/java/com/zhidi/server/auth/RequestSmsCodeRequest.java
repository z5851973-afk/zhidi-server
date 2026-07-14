package com.zhidi.server.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record RequestSmsCodeRequest(
	@NotBlank
	@Pattern(regexp = "1[3-9]\\d{9}")
	String phone
) {
}
