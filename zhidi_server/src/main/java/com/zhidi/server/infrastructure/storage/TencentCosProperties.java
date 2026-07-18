package com.zhidi.server.infrastructure.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "tencent.cos")
public record TencentCosProperties(
	String secretId,
	String secretKey,
	String bucket,
	String region) {
}
