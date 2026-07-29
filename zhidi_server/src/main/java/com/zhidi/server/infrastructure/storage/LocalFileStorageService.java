package com.zhidi.server.infrastructure.storage;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(prefix = "tencent.cos", name = "enabled", havingValue = "false", matchIfMissing = true)
public class LocalFileStorageService implements FileStorageService {

	private final Path uploadRoot;

	public LocalFileStorageService(@Value("${zhidi.upload.root:./uploads}") String uploadRoot) {
		this.uploadRoot = Path.of(uploadRoot).toAbsolutePath().normalize();
	}

	@Override
	public String upload(String objectKey, byte[] data, String contentType) {
		Path target = resolveSafely(objectKey);
		try {
			Files.createDirectories(target.getParent());
			Files.write(target, data, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
			return publicUrl(objectKey);
		} catch (IOException exception) {
			throw new StorageException("文件保存失败，请稍后重试", exception);
		}
	}

	@Override
	public String presignUrl(String objectKey, Duration ttl) {
		resolveSafely(objectKey);
		return publicUrl(objectKey);
	}

	@Override
	public void delete(String objectKey) {
		try {
			Files.deleteIfExists(resolveSafely(objectKey));
		} catch (IOException exception) {
			throw new StorageException("文件删除失败，请稍后重试", exception);
		}
	}

	private Path resolveSafely(String objectKey) {
		if (objectKey == null || objectKey.isBlank() || objectKey.startsWith("/")) {
			throw new IllegalArgumentException("objectKey is invalid");
		}
		Path target = uploadRoot.resolve(objectKey).normalize();
		if (!target.startsWith(uploadRoot)) {
			throw new IllegalArgumentException("objectKey escapes upload root");
		}
		return target;
	}

	private String publicUrl(String objectKey) {
		return "/uploads/" + objectKey.replace('\\', '/');
	}

	public static final class StorageException extends RuntimeException {
		public StorageException(String message, Throwable cause) {
			super(message, cause);
		}
	}
}
