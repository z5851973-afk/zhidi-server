package com.zhidi.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhidi.server.account.UserRole;
import io.jsonwebtoken.Claims;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class JwtTokenServiceTest {

	private static final Instant NOW = Instant.parse("2026-07-14T01:00:00Z");

	@Test
	void issuesAThirtyDayTokenWithOwnerClaims() {
		UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000001");
		JwtTokenService service = new JwtTokenService(
			"test-only-jwt-signing-secret-at-least-32-bytes",
			Duration.ofDays(30), Clock.fixed(NOW, ZoneOffset.UTC));

		JwtTokenResult result = service.issue(
			userId, "16600000002", Set.of(UserRole.OWNER));
		Claims claims = service.parse(result.accessToken());

		assertThat(result.expiresInSeconds()).isEqualTo(2_592_000);
		assertThat(claims.getSubject()).isEqualTo(userId.toString());
		assertThat(claims.get("phone", String.class)).isEqualTo("16600000002");
		assertThat(claims.get("roles", List.class)).containsExactly("OWNER");
		assertThat(claims.getIssuedAt().toInstant()).isEqualTo(NOW);
		assertThat(claims.getExpiration().toInstant()).isEqualTo(NOW.plus(Duration.ofDays(30)));
	}

	@Test
	void rejectsSigningSecretsShorterThanThirtyTwoBytes() {
		assertThatThrownBy(() -> new JwtTokenService(
			"too-short", Duration.ofDays(30), Clock.fixed(NOW, ZoneOffset.UTC)))
			.isInstanceOf(IllegalArgumentException.class)
			.hasMessageContaining("32 bytes");
	}
}
