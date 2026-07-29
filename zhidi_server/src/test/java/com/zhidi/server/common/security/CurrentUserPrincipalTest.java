package com.zhidi.server.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhidi.server.account.UserRole;
import java.security.Principal;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class CurrentUserPrincipalTest {

	@Test
	void exposesUuidAsWebSocketPrincipalName() {
		UUID userId = UUID.randomUUID();
		CurrentUserPrincipal principal = new CurrentUserPrincipal(
			userId, "13800138000", Set.of(UserRole.OWNER));

		assertThat(principal).isInstanceOf(Principal.class);
		assertThat(((Principal) principal).getName()).isEqualTo(userId.toString());
	}
}
