package com.zhidi.server.infrastructure.sms;

import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(prefix = "tencent.sms", name = "enabled", havingValue = "false", matchIfMissing = true)
public class NoOpSmsService implements SmsService {

	private static final Logger log = LoggerFactory.getLogger(NoOpSmsService.class);
	@Override
	public void sendVerificationCode(String phoneNumber, String code) {
		log.info("[DEV] SMS verify code for {}: {}", phoneNumber, code);
	}

	@Override
	public void sendNotification(String phoneNumber, String templateId, Map<String, String> params) {
		log.info("[DEV] SMS notification to {}: template={} params={}", phoneNumber, templateId, params);
	}
}
