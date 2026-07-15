package com.zhidi.server.common.security;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.auth.JwtTokenService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Collections;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

	private static final String BEARER_PREFIX = "Bearer ";

	private final JwtTokenService jwtTokenService;
	private final UserRepository userRepository;
	private final SecurityErrorWriter errorWriter;

	public JwtAuthenticationFilter(JwtTokenService jwtTokenService,
			UserRepository userRepository, SecurityErrorWriter errorWriter) {
		this.jwtTokenService = jwtTokenService;
		this.userRepository = userRepository;
		this.errorWriter = errorWriter;
	}

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		String path = request.getRequestURI();
		return !path.startsWith("/api/v1/")
			|| path.startsWith("/api/v1/auth/")
			|| isPublicWorkerDirectoryGet(request, path);
	}

	private boolean isPublicWorkerDirectoryGet(HttpServletRequest request, String path) {
		if (!HttpMethod.GET.matches(request.getMethod())) {
			return false;
		}
		return path.equals("/api/v1/workers")
			|| (path.startsWith("/api/v1/workers/") && !path.equals("/api/v1/workers/me"));
	}

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
			FilterChain filterChain) throws ServletException, IOException {
		SecurityContextHolder.clearContext();
		Optional<String> token = bearerToken(request);
		if (token.isEmpty()) {
			unauthorized(response, "AUTHENTICATION_REQUIRED", "authentication required");
			return;
		}

		UsernamePasswordAuthenticationToken authentication;
		try {
			Claims claims = jwtTokenService.verify(token.orElseThrow());
			UUID userId = UUID.fromString(claims.getSubject());
			Optional<User> storedUser = userRepository.findById(userId);
			if (storedUser.isEmpty()) {
				unauthorized(response, "TOKEN_INVALID", "access token invalid");
				return;
			}

			User user = storedUser.orElseThrow();
			if (user.getStatus() == UserStatus.DISABLED) {
				errorWriter.write(response, HttpStatus.FORBIDDEN,
					"ACCOUNT_DISABLED", "account disabled");
				return;
			}

			CurrentUserPrincipal principal = new CurrentUserPrincipal(
				userId, user.getPhone(), user.getRoles());
			authentication =
				UsernamePasswordAuthenticationToken.authenticated(
					principal, null, principal.authorities());
		}
		catch (ExpiredJwtException exception) {
			unauthorized(response, "TOKEN_EXPIRED", "access token expired");
			return;
		}
		catch (JwtException | IllegalArgumentException exception) {
			unauthorized(response, "TOKEN_INVALID", "access token invalid");
			return;
		}

		SecurityContextHolder.getContext().setAuthentication(authentication);
		try {
			filterChain.doFilter(request, response);
		}
		finally {
			SecurityContextHolder.clearContext();
		}
	}

	private Optional<String> bearerToken(HttpServletRequest request) {
		var headers = Collections.list(request.getHeaders(HttpHeaders.AUTHORIZATION));
		if (headers.size() != 1) {
			return Optional.empty();
		}
		String authorization = headers.getFirst();
		if (authorization == null || !authorization.startsWith(BEARER_PREFIX)) {
			return Optional.empty();
		}
		String token = authorization.substring(BEARER_PREFIX.length());
		return StringUtils.hasText(token) ? Optional.of(token) : Optional.empty();
	}

	private void unauthorized(HttpServletResponse response, String code, String message)
			throws IOException {
		errorWriter.write(response, HttpStatus.UNAUTHORIZED, code, message);
	}
}
