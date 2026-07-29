package com.zhidi.server.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class LocalFileStorageServiceTest {

	@TempDir
	Path uploadRoot;

	@Test
	void uploadPersistsBytesAndReturnsPublicUrl() throws Exception {
		LocalFileStorageService storage = new LocalFileStorageService(uploadRoot.toString());

		String url = storage.upload("chat/2026/07/22/photo.jpg", new byte[] {1, 2, 3}, "image/jpeg");

		assertThat(url).isEqualTo("/uploads/chat/2026/07/22/photo.jpg");
		assertThat(Files.readAllBytes(uploadRoot.resolve("chat/2026/07/22/photo.jpg")))
			.containsExactly(1, 2, 3);
		assertThat(storage.presignUrl("chat/2026/07/22/photo.jpg", Duration.ofMinutes(5)))
			.isEqualTo(url);
	}

	@Test
	void rejectsObjectKeysThatEscapeUploadRoot() {
		LocalFileStorageService storage = new LocalFileStorageService(uploadRoot.toString());

		assertThatThrownBy(() -> storage.upload("../secret.txt", new byte[] {1}, "text/plain"))
			.isInstanceOf(IllegalArgumentException.class)
			.hasMessageContaining("objectKey");
	}

	@Test
	void deleteRemovesPersistedObject() throws Exception {
		LocalFileStorageService storage = new LocalFileStorageService(uploadRoot.toString());
		storage.upload("daily-reports/photo.png", new byte[] {4, 5}, "image/png");

		storage.delete("daily-reports/photo.png");

		assertThat(uploadRoot.resolve("daily-reports/photo.png")).doesNotExist();
	}
}
