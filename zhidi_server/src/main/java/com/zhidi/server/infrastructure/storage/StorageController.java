package com.zhidi.server.infrastructure.storage;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/v1/storage")
public class StorageController {

	private static final long MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

	private final FileStorageService storage;

	public StorageController(FileStorageService storage) {
		this.storage = storage;
	}

	@PostMapping("/upload")
	@PreAuthorize("hasAnyRole('WORKER', 'OWNER')")
	public ResponseEntity<ApiResponse<UploadResponse>> upload(
			@RequestParam("file") MultipartFile file,
			@RequestParam(value = "category", defaultValue = "uploads") String category) {
		if (file.isEmpty()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "文件为空");
		}
		if (file.getSize() > MAX_FILE_SIZE) {
			throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "文件超过 10MB 限制");
		}

		String contentType = file.getContentType();
		if (contentType == null) {
			contentType = "application/octet-stream";
		}

		String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd"));
		String originalName = file.getOriginalFilename();
		String extension = "";
		if (originalName != null && originalName.contains(".")) {
			extension = originalName.substring(originalName.lastIndexOf('.'));
		}
		String objectKey = category + "/" + today + "/" + UUID.randomUUID() + extension;

		byte[] data;
		try {
			data = file.getBytes();
		} catch (Exception e) {
			throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "读取文件失败");
		}

		String url = storage.upload(objectKey, data, contentType);
		String downloadUrl = "https://" + System.getenv().getOrDefault("CDN_DOMAIN",
			System.getenv().getOrDefault("TENCENT_COS_BUCKET", "zhidi-uploads") +
			".cos.ap-guangzhou.myqcloud.com") + "/" + objectKey;

		return ResponseEntity.ok(ApiResponse.ok(
			new UploadResponse(url, objectKey), traceId()));
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}

	public record UploadResponse(String url, String objectKey) {}
}
