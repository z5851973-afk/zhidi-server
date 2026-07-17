package com.zhidi.server.storage;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
public class ImageUploadController {

	private final ImageStorageService storage;

	public ImageUploadController(ImageStorageService storage) {
		this.storage = storage;
	}

	@PostMapping("/api/v1/workers/me/case-images")
	@PreAuthorize("hasRole('WORKER')")
	@ResponseStatus(HttpStatus.CREATED)
	public ApiResponse<ImageUploadResponse> upload(@RequestParam("file") MultipartFile file) {
		String path = storage.store(file);
		String url = ServletUriComponentsBuilder.fromCurrentContextPath()
			.path(path).toUriString();
		return ApiResponse.ok(new ImageUploadResponse(url), MDC.get(TraceIdFilter.MDC_KEY));
	}
}
