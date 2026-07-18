package com.zhidi.server.infrastructure.storage;

import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnMissingBean(value = FileStorageService.class, ignored = NoOpFileStorageService.class)
public class NoOpFileStorageService implements FileStorageService {

	private static final Logger log = LoggerFactory.getLogger(NoOpFileStorageService.class);

	@Override
	public String upload(String objectKey, byte[] data, String contentType) {
		log.info("[DEV] File upload ({} bytes): {} (type={})", data.length, objectKey, contentType);
		return "file://dev/" + objectKey;
	}

	@Override
	public String presignUrl(String objectKey, Duration ttl) {
		log.info("[DEV] Presign URL: {}, ttl={}", objectKey, ttl);
		return "file://dev/" + objectKey;
	}

	@Override
	public void delete(String objectKey) {
		log.info("[DEV] File delete: {}", objectKey);
	}
}
