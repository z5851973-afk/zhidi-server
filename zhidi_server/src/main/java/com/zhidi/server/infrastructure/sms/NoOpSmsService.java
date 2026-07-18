package com.zhidi.server.infrastructure.sms;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnMissingBean(value = SmsService.class, ignored = NoOpSmsService.class)
public class NoOpSmsService implements SmsService {

	private static final Logger log = LoggerFactory.getLogger(NoOpSmsService.class);
	private static final Duration CODE_TTL = Duration.ofMinutes(5);
	private static final Duration COOLDOWN = Duration.ofSeconds(60);

	private final SecureRandom random = new SecureRandom();
	private final Map<String, CodeEntry> codes = new ConcurrentHashMap<>();
	private final Map<String, Long> cooldowns = new ConcurrentHashMap<>();

	@Override
	public SmsSendResult sendVerifyCode(String phoneNumber) {
		long now = System.currentTimeMillis();
		Long lastSent = cooldowns.get(phoneNumber);
		if (lastSent != null && (now - lastSent) < COOLDOWN.toMillis()) {
			long retryAfter = (COOLDOWN.toMillis() - (now - lastSent)) / 1000;
			return SmsSendResult.rateLimited(retryAfter);
		}

		String code = "%06d".formatted(random.nextInt(1_000_000));
		log.info("[DEV] SMS verify code for {}: {}", phoneNumber, code);

		codes.put(phoneNumber, new CodeEntry(code, now + CODE_TTL.toMillis()));
		cooldowns.put(phoneNumber, now);
		return SmsSendResult.success(code, CODE_TTL.toSeconds(), COOLDOWN.toSeconds());
	}

	@Override
	public boolean verifyCode(String phoneNumber, String code) {
		long now = System.currentTimeMillis();
		CodeEntry entry = codes.get(phoneNumber);
		if (entry == null || entry.expiresAt < now) {
			return false;
		}
		return entry.code.equals(code);
	}

	@Override
	public void sendNotification(String phoneNumber, String templateId, Map<String, String> params) {
		log.info("[DEV] SMS notification to {}: template={} params={}", phoneNumber, templateId, params);
	}

	private record CodeEntry(String code, long expiresAt) {}
}
