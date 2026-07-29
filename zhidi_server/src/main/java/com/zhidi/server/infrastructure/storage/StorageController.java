package com.zhidi.server.infrastructure.storage;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;
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
	private static final Pattern CATEGORY_PATTERN = Pattern.compile("[a-z0-9-]{1,40}");
	private static final Map<String, String> IMAGE_EXTENSIONS = Map.of(
		"image/jpeg", ".jpg",
		"image/png", ".png",
		"image/webp", ".webp"
	);

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
		if (!CATEGORY_PATTERN.matcher(category).matches()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "文件分类不合法");
		}

		String contentType = file.getContentType();
		String extension = IMAGE_EXTENSIONS.get(contentType);
		if (extension == null) {
			throw new ResponseStatusException(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "仅支持 JPG、PNG、WEBP 图片");
		}

		String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd"));
		String objectKey = category + "/" + today + "/" + UUID.randomUUID() + extension;

		byte[] data;
		try {
			data = file.getBytes();
		} catch (Exception e) {
			throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "读取文件失败");
		}

		String url = storage.upload(objectKey, data, contentType);

		return ResponseEntity.ok(ApiResponse.ok(
			new UploadResponse(url, objectKey), traceId()));
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}

	public record UploadResponse(String url, String objectKey) {}
}
