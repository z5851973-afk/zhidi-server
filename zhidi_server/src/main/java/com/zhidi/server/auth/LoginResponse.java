package com.zhidi.server.auth;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "业主登录成功响应")
public record LoginResponse(
	@Schema(description = "JWT 访问令牌") String accessToken,
	@Schema(description = "令牌类型", example = "Bearer") String tokenType,
	@Schema(description = "令牌剩余有效秒数", example = "2592000") long expiresInSeconds,
	@Schema(description = "已登录业主") AuthUserResponse user
) {
}
