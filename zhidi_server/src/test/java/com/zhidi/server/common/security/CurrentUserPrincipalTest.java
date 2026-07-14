package com.zhidi.server.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhidi.server.account.UserRole;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.GrantedAuthority;

class CurrentUserPrincipalTest {

	@Test
	void mapsCurrentDatabaseRolesToSpringAuthorities() {
		UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000001");
		CurrentUserPrincipal principal = new CurrentUserPrincipal(
			userId, "16600000002", Set.of(UserRole.ADMIN, UserRole.OWNER));

		assertThat(principal.authorities())
			.extracting(GrantedAuthority::getAuthority)
			.containsExactly("ROLE_ADMIN", "ROLE_OWNER");
		assertThat(principal.roles()).isUnmodifiable();
	}
}
