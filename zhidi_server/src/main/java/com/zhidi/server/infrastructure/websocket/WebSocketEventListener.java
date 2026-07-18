package com.zhidi.server.infrastructure.websocket;

import java.security.Principal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

@Component
public class WebSocketEventListener {

	private static final Logger log = LoggerFactory.getLogger(WebSocketEventListener.class);

	@EventListener
	public void handleConnect(SessionConnectEvent event) {
		Principal user = event.getUser();
		if (user != null) {
			log.info("WebSocket connected: user={}", user.getName());
		}
	}

	@EventListener
	public void handleDisconnect(SessionDisconnectEvent event) {
		Principal user = event.getUser();
		if (user != null) {
			log.info("WebSocket disconnected: user={}", user.getName());
		}
	}
}
