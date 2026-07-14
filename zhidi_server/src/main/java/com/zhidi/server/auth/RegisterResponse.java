package com.zhidi.server.auth;

import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import java.util.Set;
import java.util.UUID;

public record RegisterResponse(
	UUID id,
	String phone,
	UserStatus status,
	Set<UserRole> roles
) {
}
