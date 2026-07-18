package com.zhidi.server.infrastructure.websocket;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserStatus;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import io.jsonwebtoken.Claims;
import java.util.Optional;
import java.util.UUID;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
public class StompJwtChannelInterceptor implements ChannelInterceptor {

	private static final String BEARER_PREFIX = "Bearer ";

	private final JwtTokenService jwtTokenService;
	private final UserRepository userRepository;

	public StompJwtChannelInterceptor(JwtTokenService jwtTokenService,
			UserRepository userRepository) {
		this.jwtTokenService = jwtTokenService;
		this.userRepository = userRepository;
	}

	@Override
	public Message<?> preSend(Message<?> message, MessageChannel channel) {
		StompHeaderAccessor accessor = MessageHeaderAccessor
			.getAccessor(message, StompHeaderAccessor.class);
		if (accessor == null) return message;

		if (StompCommand.CONNECT.equals(accessor.getCommand())) {
			String authHeader = accessor.getFirstNativeHeader("Authorization");
			if (authHeader == null || !authHeader.startsWith(BEARER_PREFIX)) {
				throw new IllegalArgumentException("authentication required");
			}

			String token = authHeader.substring(BEARER_PREFIX.length());
			Claims claims = jwtTokenService.verify(token);
			UUID userId = UUID.fromString(claims.getSubject());

			Optional<User> user = userRepository.findById(userId);
			if (user.isEmpty() || user.get().getStatus() == UserStatus.DISABLED) {
				throw new IllegalArgumentException("invalid token");
			}

			CurrentUserPrincipal principal = new CurrentUserPrincipal(
				userId, user.get().getPhone(), user.get().getRoles());
			UsernamePasswordAuthenticationToken auth =
				UsernamePasswordAuthenticationToken.authenticated(
					principal, null, principal.authorities());
			accessor.setUser(auth);
		}

		return message;
	}
}
