package com.zhidi.server.storage;

import com.zhidi.server.common.error.BusinessException;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ImageStorageService {

	private static final Map<String, String> EXTENSIONS = Map.of(
		"image/jpeg", "jpg",
		"image/png", "png",
		"image/webp", "webp");

	private final Path root;
	private final long maxBytes;

	@Autowired
	public ImageStorageService(
			@Value("${zhidi.upload.root:./uploads}") String root,
			@Value("${zhidi.upload.max-image-bytes:10485760}") long maxBytes) {
		this(Path.of(root), maxBytes);
	}

	ImageStorageService(Path root, long maxBytes) {
		this.root = root.toAbsolutePath().normalize();
		this.maxBytes = maxBytes;
	}

	public String store(MultipartFile file) {
		if (file == null || file.isEmpty()) {
			throw error(HttpStatus.BAD_REQUEST, "IMAGE_EMPTY", "image file is empty");
		}
		if (file.getSize() > maxBytes) {
			throw error(HttpStatus.PAYLOAD_TOO_LARGE, "IMAGE_TOO_LARGE",
				"image file exceeds 10MB");
		}
		String contentType = file.getContentType() == null
			? "" : file.getContentType().toLowerCase(Locale.ROOT);
		String extension = EXTENSIONS.get(contentType);
		if (extension == null) {
			throw error(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "IMAGE_TYPE_UNSUPPORTED",
				"only JPG, PNG and WebP are supported");
		}
		byte[] header = readHeader(file);
		if (!matchesContent(extension, header)) {
			throw error(HttpStatus.BAD_REQUEST, "IMAGE_CONTENT_INVALID",
				"image content does not match its type");
		}

		String filename = UUID.randomUUID() + "." + extension;
		Path directory = root.resolve("cases");
		Path target = directory.resolve(filename).normalize();
		if (!target.startsWith(directory.normalize())) {
			throw error(HttpStatus.BAD_REQUEST, "IMAGE_PATH_INVALID", "image path is invalid");
		}
		try {
			Files.createDirectories(directory);
			try (InputStream input = file.getInputStream()) {
				Files.copy(input, target);
			}
		} catch (IOException error) {
			throw error(HttpStatus.INTERNAL_SERVER_ERROR, "IMAGE_STORAGE_FAILED",
				"image could not be stored");
		}
		return "/uploads/cases/" + filename;
	}

	private byte[] readHeader(MultipartFile file) {
		try (InputStream input = file.getInputStream()) {
			return input.readNBytes(12);
		} catch (IOException error) {
			throw error(HttpStatus.BAD_REQUEST, "IMAGE_CONTENT_INVALID",
				"image content could not be read");
		}
	}

	private boolean matchesContent(String extension, byte[] bytes) {
		return switch (extension) {
			case "jpg" -> bytes.length >= 3
				&& unsigned(bytes[0]) == 0xff && unsigned(bytes[1]) == 0xd8
				&& unsigned(bytes[2]) == 0xff;
			case "png" -> bytes.length >= 8
				&& unsigned(bytes[0]) == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e
				&& bytes[3] == 0x47 && bytes[4] == 0x0d && bytes[5] == 0x0a
				&& bytes[6] == 0x1a && bytes[7] == 0x0a;
			case "webp" -> bytes.length >= 12
				&& bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F'
				&& bytes[8] == 'W' && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P';
			default -> false;
		};
	}

	private int unsigned(byte value) {
		return value & 0xff;
	}

	private BusinessException error(HttpStatus status, String code, String message) {
		return new BusinessException(status, code, message);
	}
}
