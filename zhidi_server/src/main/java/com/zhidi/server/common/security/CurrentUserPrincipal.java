package com.zhidi.server.common.security;

import com.zhidi.server.account.UserRole;
import java.util.Collection;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.util.StringUtils;

public record CurrentUserPrincipal(UUID userId, String phone, Set<UserRole> roles) {

	public CurrentUserPrincipal {
		Objects.requireNonNull(userId, "userId must not be null");
		if (!StringUtils.hasText(phone)) {
			throw new IllegalArgumentException("phone must not be blank");
		}
		roles = Set.copyOf(roles);
	}

	public Collection<? extends GrantedAuthority> authorities() {
		return roles.stream()
			.map(Enum::name)
			.sorted()
			.map(role -> new SimpleGrantedAuthority("ROLE_" + role))
			.toList();
	}
}
