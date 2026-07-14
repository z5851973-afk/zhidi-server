package com.zhidi.server.common.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.doThrow;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.auth.JwtTokenService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Header;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

class JwtAuthenticationFilterTest {

	private static final String TOKEN = "signed-token";
	private static final UUID USER_ID = UUID.fromString("01904f24-3f5b-7000-8000-000000000001");

	private JwtTokenService jwtTokenService;
	private UserRepository userRepository;
	private SecurityErrorWriter errorWriter;
	private ObjectMapper objectMapper;
	private FilterChain chain;
	private MockHttpServletResponse response;
	private JwtAuthenticationFilter filter;

	@BeforeEach
	void setUp() {
		jwtTokenService = mock(JwtTokenService.class);
		userRepository = mock(UserRepository.class);
		objectMapper = new ObjectMapper();
		errorWriter = new SecurityErrorWriter(objectMapper);
		chain = mock(FilterChain.class);
		response = new MockHttpServletResponse();
		filter = new JwtAuthenticationFilter(jwtTokenService, userRepository, errorWriter);
	}

	@AfterEach
	void clearSecurityContext() {
		SecurityContextHolder.clearContext();
	}

	@Test
	void ignoresPublicAuthenticationPathsEvenWithABadToken() throws Exception {
		MockHttpServletRequest request = request("/api/v1/auth/login");
		request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer broken");

		filter.doFilter(request, response, chain);

		verify(chain).doFilter(request, response);
		verifyNoInteractions(jwtTokenService, userRepository);
		assertThat(response.getContentAsByteArray()).isEmpty();
	}

	@Test
	void ignoresRequestsOutsideTheVersionedApi() throws Exception {
		MockHttpServletRequest request = request("/actuator/health");

		filter.doFilter(request, response, chain);

		verify(chain).doFilter(request, response);
		verifyNoInteractions(jwtTokenService, userRepository);
		assertThat(response.getContentAsByteArray()).isEmpty();
	}

	@Test
	void rejectsProtectedRequestsWithoutABearerToken() throws Exception {
		MockHttpServletRequest request = request("/api/v1/owners/me");

		filter.doFilter(request, response, chain);

		assertErrorResponse(HttpStatus.UNAUTHORIZED,
			"AUTHENTICATION_REQUIRED", "authentication required");
		verifyNoInteractions(chain);
		assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
	}

	@Test
	void rejectsBearerTokenContainingOnlyWhitespace() throws Exception {
		MockHttpServletRequest request = request("/api/v1/owners/me");
		request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer   ");

		filter.doFilter(request, response, chain);

		assertErrorResponse(HttpStatus.UNAUTHORIZED,
			"AUTHENTICATION_REQUIRED", "authentication required");
		verifyNoInteractions(jwtTokenService, userRepository, chain);
	}

	@Test
	void rejectsMultipleAuthorizationHeaders() throws Exception {
		MockHttpServletRequest request = bearerRequest();
		request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer another-token");

		filter.doFilter(request, response, chain);

		assertErrorResponse(HttpStatus.UNAUTHORIZED,
			"AUTHENTICATION_REQUIRED", "authentication required");
		verifyNoInteractions(jwtTokenService, userRepository, chain);
	}

	@Test
	void authenticatesUsingCurrentDatabasePhoneAndRoles() throws Exception {
		Claims claims = mock(Claims.class);
		User user = mock(User.class);
		given(jwtTokenService.verify(TOKEN)).willReturn(claims);
		given(claims.getSubject()).willReturn(USER_ID.toString());
		given(claims.get("roles")).willReturn(Set.of("ADMIN"));
		given(userRepository.findById(USER_ID)).willReturn(Optional.of(user));
		given(user.getStatus()).willReturn(UserStatus.ACTIVE);
		given(user.getPhone()).willReturn("16600000002");
		given(user.getRoles()).willReturn(Set.of(UserRole.OWNER));
		AtomicReference<Authentication> authenticationInChain = new AtomicReference<>();
		givenChainCapturesAuthentication(authenticationInChain);

		filter.doFilter(bearerRequest(), response, chain);

		Authentication authentication = authenticationInChain.get();
		assertThat(authentication).isNotNull();
		assertThat(authentication.isAuthenticated()).isTrue();
		assertThat(authentication.getPrincipal()).isEqualTo(
			new CurrentUserPrincipal(USER_ID, "16600000002", Set.of(UserRole.OWNER)));
		assertThat(authentication.getAuthorities())
			.extracting(GrantedAuthority::getAuthority)
			.containsExactly("ROLE_OWNER");
		assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
	}

	@Test
	void clearsAuthenticationAndPropagatesDownstreamFailures() throws Exception {
		User user = mock(User.class);
		claimsForUser();
		given(userRepository.findById(USER_ID)).willReturn(Optional.of(user));
		given(user.getStatus()).willReturn(UserStatus.ACTIVE);
		given(user.getPhone()).willReturn("16600000002");
		given(user.getRoles()).willReturn(Set.of(UserRole.OWNER));
		doThrow(new IllegalArgumentException("downstream failure"))
			.when(chain).doFilter(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());

		assertThatThrownBy(() -> filter.doFilter(bearerRequest(), response, chain))
			.isInstanceOf(IllegalArgumentException.class)
			.hasMessage("downstream failure");
		assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
		assertThat(response.getContentAsByteArray()).isEmpty();
	}

	@Test
	void mapsExpiredTokenToTokenExpired() throws Exception {
		given(jwtTokenService.verify(TOKEN)).willThrow(new ExpiredJwtException(
			mock(Header.class), mock(Claims.class), "expired"));

		filter.doFilter(bearerRequest(), response, chain);

		assertRejected(HttpStatus.UNAUTHORIZED, "TOKEN_EXPIRED", "access token expired");
	}

	@Test
	void mapsInvalidJwtToTokenInvalid() throws Exception {
		given(jwtTokenService.verify(TOKEN)).willThrow(new JwtException("bad token"));

		filter.doFilter(bearerRequest(), response, chain);

		assertRejected(HttpStatus.UNAUTHORIZED, "TOKEN_INVALID", "access token invalid");
	}

	@Test
	void mapsInvalidSubjectToTokenInvalid() throws Exception {
		Claims claims = mock(Claims.class);
		given(jwtTokenService.verify(TOKEN)).willReturn(claims);
		given(claims.getSubject()).willReturn("not-a-uuid");

		filter.doFilter(bearerRequest(), response, chain);

		assertRejected(HttpStatus.UNAUTHORIZED, "TOKEN_INVALID", "access token invalid");
	}

	@Test
	void mapsMissingDatabaseUserToTokenInvalid() throws Exception {
		Claims claims = claimsForUser();
		given(userRepository.findById(USER_ID)).willReturn(Optional.empty());

		filter.doFilter(bearerRequest(), response, chain);

		assertRejected(HttpStatus.UNAUTHORIZED, "TOKEN_INVALID", "access token invalid");
	}

	@Test
	void rejectsDisabledDatabaseUser() throws Exception {
		User user = mock(User.class);
		claimsForUser();
		given(userRepository.findById(USER_ID)).willReturn(Optional.of(user));
		given(user.getStatus()).willReturn(UserStatus.DISABLED);

		filter.doFilter(bearerRequest(), response, chain);

		assertRejected(HttpStatus.FORBIDDEN, "ACCOUNT_DISABLED", "account disabled");
	}

	private Claims claimsForUser() {
		Claims claims = mock(Claims.class);
		given(jwtTokenService.verify(TOKEN)).willReturn(claims);
		given(claims.getSubject()).willReturn(USER_ID.toString());
		return claims;
	}

	private void givenChainCapturesAuthentication(AtomicReference<Authentication> authentication) throws Exception {
		org.mockito.Mockito.doAnswer(invocation -> {
			authentication.set(SecurityContextHolder.getContext().getAuthentication());
			return null;
		}).when(chain).doFilter(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
	}

	private void assertRejected(HttpStatus status, String code, String message) throws Exception {
		assertErrorResponse(status, code, message);
		verifyNoInteractions(chain);
		assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
	}

	private void assertErrorResponse(HttpStatus status, String code, String message) throws Exception {
		JsonNode body = objectMapper.readTree(response.getContentAsByteArray());
		assertThat(response.getStatus()).isEqualTo(status.value());
		assertThat(body.path("code").asText()).isEqualTo(code);
		assertThat(body.path("message").asText()).isEqualTo(message);
	}

	private MockHttpServletRequest bearerRequest() {
		MockHttpServletRequest request = request("/api/v1/owners/me");
		request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer " + TOKEN);
		return request;
	}

	private MockHttpServletRequest request(String path) {
		return new MockHttpServletRequest("GET", path);
	}
}
