package com.zhidi.server.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhidi.server.common.error.BusinessException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;

class ImageStorageServiceTest {

	@TempDir
	Path tempDir;

	@Test
	void storesValidatedJpegWithGeneratedName() throws Exception {
		ImageStorageService service = new ImageStorageService(tempDir, 10 * 1024 * 1024);
		byte[] jpeg = {(byte) 0xff, (byte) 0xd8, (byte) 0xff, 0x01, 0x02};

		String path = service.store(new MockMultipartFile(
			"file", "../../业主家.jpg", "image/jpeg", jpeg));

		assertThat(path).matches("/uploads/cases/[0-9a-f-]+\\.jpg");
		assertThat(Files.readAllBytes(tempDir.resolve("cases")
			.resolve(path.substring(path.lastIndexOf('/') + 1)))).isEqualTo(jpeg);
	}

	@Test
	void rejectsEmptyOversizedAndUnsupportedFiles() {
		ImageStorageService service = new ImageStorageService(tempDir, 4);

		assertCode(service, new MockMultipartFile("file", new byte[0]),
			"IMAGE_EMPTY");
		assertCode(service, new MockMultipartFile(
			"file", "large.jpg", "image/jpeg",
			new byte[] {(byte) 0xff, (byte) 0xd8, (byte) 0xff, 1, 2}),
			"IMAGE_TOO_LARGE");
		assertCode(new ImageStorageService(tempDir, 1024), new MockMultipartFile(
			"file", "note.txt", "text/plain", "hello".getBytes()),
			"IMAGE_TYPE_UNSUPPORTED");
	}

	@Test
	void rejectsImageMimeWhenBytesDoNotMatch() {
		ImageStorageService service = new ImageStorageService(tempDir, 1024);

		assertCode(service, new MockMultipartFile(
			"file", "fake.png", "image/png", "not-png".getBytes()),
			"IMAGE_CONTENT_INVALID");
	}

	private void assertCode(ImageStorageService service, MockMultipartFile file,
			String code) {
		assertThatThrownBy(() -> service.store(file))
			.isInstanceOfSatisfying(BusinessException.class,
				error -> assertThat(error.code()).isEqualTo(code));
	}
}
