package com.zhidi.server.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.server.ResponseStatusException;

class StorageControllerTest {

	private final FileStorageService storage = mock(FileStorageService.class);
	private final StorageController controller = new StorageController(storage);

	@Test
	void usesServerApprovedExtensionInsteadOfOriginalFilename() {
		MockMultipartFile file = new MockMultipartFile(
			"file", "attack.exe", "image/png", new byte[] {1, 2});
		when(storage.upload(any(), any(), eq("image/png")))
			.thenAnswer(invocation -> "/uploads/" + invocation.getArgument(0, String.class));

		var response = controller.upload(file, "chat");
		var body = response.getBody();

		assertThat(body).isNotNull();
		assertThat(body.data().objectKey()).startsWith("chat/").endsWith(".png");
		assertThat(body.data().url()).startsWith("/uploads/chat/");
	}

	@Test
	void rejectsTraversalCategory() {
		MockMultipartFile file = new MockMultipartFile(
			"file", "photo.jpg", "image/jpeg", new byte[] {1});

		assertThatThrownBy(() -> controller.upload(file, "../outside"))
			.isInstanceOfSatisfying(ResponseStatusException.class,
				exception -> assertThat(exception.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST));
	}

	@Test
	void rejectsNonImageContent() {
		MockMultipartFile file = new MockMultipartFile(
			"file", "payload.txt", "text/plain", new byte[] {1});

		assertThatThrownBy(() -> controller.upload(file, "chat"))
			.isInstanceOfSatisfying(ResponseStatusException.class,
				exception -> assertThat(exception.getStatusCode()).isEqualTo(HttpStatus.UNSUPPORTED_MEDIA_TYPE));
	}
}
