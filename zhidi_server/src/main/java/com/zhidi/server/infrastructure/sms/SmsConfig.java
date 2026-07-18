package com.zhidi.server.infrastructure.sms;

import java.util.Map;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "tencent.sms")
public record SmsConfig(
	String secretId,
	String secretKey,
	String appId,
	String signName,
	Map<String, String> templateIds) {
}
