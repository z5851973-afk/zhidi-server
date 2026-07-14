package com.zhidi.server.auth;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AuthConfiguration {

	@Bean
	Clock clock() {
		return Clock.systemUTC();
	}
}
