package com.zhidi.server.payment.provider;

import java.time.Instant;
import java.util.Map;

public record PaymentIntent(
	String provider,
	String providerOrderId,
	Map<String, String> launchParameters,
	Instant expiresAt
) {}
