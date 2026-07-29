package com.zhidi.server.common.security;

import com.zhidi.server.common.api.TraceIdFilter;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.security.authorization.AuthorizationDeniedException;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

	private static final String[] PUBLIC_PATHS = {
		"/api/v1/auth/**",
		"/actuator/health/**",
		"/v3/api-docs/**",
		"/swagger-ui/**",
		"/swagger-ui.html"
	};

	@Bean
	SecurityFilterChain securityFilterChain(HttpSecurity http,
			JwtAuthenticationFilter jwtFilter, TraceIdFilter traceIdFilter,
			SecurityErrorWriter errors) throws Exception {
		return http
			.csrf(AbstractHttpConfigurer::disable)
			.sessionManagement(session -> session
				.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
			.authorizeHttpRequests(authorize -> authorize
				.requestMatchers(PUBLIC_PATHS).permitAll()
				.requestMatchers(org.springframework.http.HttpMethod.GET,
					"/api/v1/workers", "/api/v1/workers/*",
					"/api/v1/workers/*/cases").permitAll()
				.requestMatchers("/api/v1/**").authenticated()
				.anyRequest().permitAll())
			.exceptionHandling(exceptions -> exceptions
				.authenticationEntryPoint((request, response, exception) ->
					errors.write(response, HttpStatus.UNAUTHORIZED,
						"AUTHENTICATION_REQUIRED", "authentication required"))
				.accessDeniedHandler((request, response, exception) ->
					errors.write(response, HttpStatus.FORBIDDEN,
						"ACCESS_DENIED", "access denied")))
			.addFilterBefore(traceIdFilter, UsernamePasswordAuthenticationFilter.class)
			.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
			.build();
	}

	@Bean
	MethodAccessDeniedAdvice methodAccessDeniedAdvice(SecurityErrorWriter errors) {
		return new MethodAccessDeniedAdvice(errors);
	}

	@RestControllerAdvice
	@Order(Ordered.HIGHEST_PRECEDENCE)
	static final class MethodAccessDeniedAdvice {

		private final SecurityErrorWriter errors;

		MethodAccessDeniedAdvice(SecurityErrorWriter errors) {
			this.errors = errors;
		}

		@ExceptionHandler(AuthorizationDeniedException.class)
		void handle(HttpServletResponse response) throws IOException {
			errors.write(response, HttpStatus.FORBIDDEN, "ACCESS_DENIED", "access denied");
		}
	}
}
