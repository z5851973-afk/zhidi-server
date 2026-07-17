package com.zhidi.server.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhidi.server.account.UserRepository;
import com.zhidi.server.auth.JwtTokenService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;

class JwtAuthenticationFilterTest {

	@Test
	void publicWorkerCaseListSkipsJwtAuthentication() {
		JwtAuthenticationFilter filter = new JwtAuthenticationFilter(
			mock(JwtTokenService.class),
			mock(UserRepository.class),
			new SecurityErrorWriter(new ObjectMapper()));
		HttpServletRequest request = mock(HttpServletRequest.class);
		when(request.getMethod()).thenReturn("GET");
		when(request.getRequestURI()).thenReturn(
			"/api/v1/workers/01904f24-3f5b-7000-8000-000000000099/cases");

		assertTrue(filter.shouldNotFilter(request));
	}
}
