package com.zhidi.server.auth;

import com.zhidi.server.account.UserRole;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class JwtTokenService {

	private final SecretKey signingKey;
	private final Duration ttl;
	private final Clock clock;

	public JwtTokenService(@Value("${auth.jwt.secret}") String secret,
			@Value("${auth.jwt.ttl:PT720H}") Duration ttl, Clock clock) {
		byte[] secretBytes = secret.getBytes(StandardCharsets.UTF_8);
		if (secretBytes.length < 32) {
			throw new IllegalArgumentException("auth.jwt.secret must contain at least 32 bytes");
		}
		if (ttl.isZero() || ttl.isNegative()) {
			throw new IllegalArgumentException("auth.jwt.ttl must be positive");
		}
		this.signingKey = Keys.hmacShaKeyFor(secretBytes);
		this.ttl = ttl;
		this.clock = clock;
	}

	public JwtTokenResult issue(UUID userId, String phone, Set<UserRole> roles) {
		Instant issuedAt = clock.instant();
		List<String> roleNames = roles.stream()
			.map(Enum::name)
			.sorted(Comparator.naturalOrder())
			.toList();
		String accessToken = Jwts.builder()
			.subject(userId.toString())
			.claim("phone", phone)
			.claim("roles", roleNames)
			.issuedAt(Date.from(issuedAt))
			.expiration(Date.from(issuedAt.plus(ttl)))
			.signWith(signingKey)
			.compact();
		return new JwtTokenResult(accessToken, ttl.toSeconds());
	}

	public Claims verify(String token) {
		return Jwts.parser()
			.verifyWith(signingKey)
			.clock(() -> Date.from(clock.instant()))
			.build()
			.parseSignedClaims(token)
			.getPayload();
	}
}
