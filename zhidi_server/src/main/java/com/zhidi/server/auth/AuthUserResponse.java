package com.zhidi.server.auth;

import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.Set;
import java.util.UUID;

@Schema(description = "已登录业主信息")
public record AuthUserResponse(
	@Schema(description = "用户 ID") UUID id,
	@Schema(description = "手机号", example = "16600000002") String phone,
	@Schema(description = "账户状态", example = "ACTIVE") UserStatus status,
	@Schema(description = "用户角色") Set<UserRole> roles
) {
}
