package com.zhidi.server.auth;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

@Schema(description = "业主短信验证码登录请求")
public record LoginRequest(
	@Schema(description = "中国大陆手机号", example = "16600000002")
	@NotBlank
	@Pattern(regexp = "1[3-9]\\d{9}")
	String phone,
	@Schema(description = "六位短信验证码", example = "123456")
	@NotBlank
	@Pattern(regexp = "\\d{6}")
	String code
) {
}
