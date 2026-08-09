package com.zhidi.server.dailyreport;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.notification.BusinessEventDraft;
import com.zhidi.server.notification.BusinessEventPublisher;
import com.zhidi.server.notification.BusinessEventType;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DailyReportService {
	private static final int MAX_CONTENT_LENGTH = 2000;
	private static final int MAX_PHOTO_COUNT = 9;
	private static final int MAX_PHOTO_URL_LENGTH = 2048;

	private final DailyReportRepository reportRepository;
	private final BookingRepository bookingRepository;
	private final BusinessEventPublisher businessEvents;
	private final Set<UploadOrigin> allowedPublicOrigins;
	private final UploadOrigin cosPublicOrigin;

	public DailyReportService(DailyReportRepository reportRepository,
			BookingRepository bookingRepository,
			BusinessEventPublisher businessEvents,
			@Value("${zhidi.upload.allowed-public-origins:}")
			String allowedPublicOrigins,
			@Value("${tencent.cos.bucket:zhidi-uploads-1234567890}") String cosBucket,
			@Value("${tencent.cos.region:ap-guangzhou}") String cosRegion) {
		this.reportRepository = reportRepository;
		this.bookingRepository = bookingRepository;
		this.businessEvents = businessEvents;
		this.allowedPublicOrigins = Arrays.stream(allowedPublicOrigins.split(","))
			.map(String::trim)
			.filter(value -> !value.isEmpty())
			.map(DailyReportService::parseConfiguredOrigin)
			.collect(Collectors.toUnmodifiableSet());
		this.cosPublicOrigin = parseConfiguredOrigin("https://" + cosBucket
			+ ".cos." + cosRegion + ".myqcloud.com");
	}

	@Transactional
	public DailyReportResponse submit(UUID workerUserId, UUID bookingId,
			DailyReportRequest request) {
		Booking booking = bookingRepository.findByIdForUpdate(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));
		if (!workerUserId.equals(booking.getWorkerUserId())) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在");
		}

		if (booking.getStatus() != BookingStatus.HIRED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有已选定(HIRED)的预约才能提交日报");
		}
		String content = validateContent(request.content());
		List<String> photos = validatePhotos(request.photos());

		int nextRevision = reportRepository
			.findFirstByBookingIdAndReportDateOrderByReportRevisionDesc(
				bookingId, request.reportDate())
			.map(report -> report.getReportRevision() + 1)
			.orElse(1);

		DailyReport report = DailyReport.create(bookingId, workerUserId,
			request.reportDate(), nextRevision, content, photos);
		DailyReport saved = reportRepository.save(report);
		businessEvents.publish(new BusinessEventDraft(
			booking.getOwnerUserId(),
			workerUserId,
			BusinessEventType.DAILY_REPORT_SUBMITTED,
			"DAILY_REPORT",
			saved.getId(),
			bookingId,
			booking.getServiceRequestId(),
			"daily-report:" + saved.getId(),
			Map.of(
				"reportDate", saved.getReportDate().toString(),
				"revision", saved.getReportRevision()),
			saved.getCreatedAt()));
		return DailyReportResponse.from(saved);
	}

	private String validateContent(String rawContent) {
		String content = rawContent == null ? "" : rawContent.trim();
		if (content.isEmpty()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"DAILY_REPORT_CONTENT_REQUIRED", "日报内容不能为空");
		}
		if (content.length() > MAX_CONTENT_LENGTH) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"DAILY_REPORT_CONTENT_TOO_LONG", "日报内容不能超过2000字");
		}
		return content;
	}

	private List<String> validatePhotos(List<String> rawPhotos) {
		List<String> photos = rawPhotos == null ? List.of() : rawPhotos;
		if (photos.size() > MAX_PHOTO_COUNT) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"DAILY_REPORT_TOO_MANY_PHOTOS", "日报照片不能超过9张");
		}
		return photos.stream().map(this::validatePhotoUrl).toList();
	}

	private String validatePhotoUrl(String rawUrl) {
		String url = rawUrl == null ? "" : rawUrl.trim();
		if (url.isEmpty() || url.length() > MAX_PHOTO_URL_LENGTH) {
			throw invalidPhoto();
		}
		try {
			URI uri = new URI(url).normalize();
			String path = uri.getPath();
			if (path == null || path.contains("..")) {
				throw invalidPhoto();
			}
			if (!uri.isAbsolute()) {
				if (uri.getHost() != null || uri.getQuery() != null
						|| !path.startsWith("/uploads/daily-reports/")) {
					throw invalidPhoto();
				}
				return url;
			}
			UploadOrigin origin = UploadOrigin.from(uri);
			boolean localUpload = allowedPublicOrigins.contains(origin)
				&& path.startsWith("/uploads/daily-reports/");
			boolean cosUpload = origin.equals(cosPublicOrigin)
				&& path.startsWith("/daily-reports/");
			if (!(localUpload || cosUpload)) {
				throw invalidPhoto();
			}
			return url;
		} catch (URISyntaxException | IllegalArgumentException exception) {
			throw invalidPhoto();
		}
	}

	private static UploadOrigin parseConfiguredOrigin(String rawOrigin) {
		try {
			URI uri = new URI(rawOrigin.trim());
			String path = uri.getPath();
			if (!uri.isAbsolute() || uri.getUserInfo() != null
					|| uri.getQuery() != null || uri.getFragment() != null
					|| (path != null && !path.isEmpty() && !path.equals("/"))) {
				throw new IllegalArgumentException("上传来源必须是完整 origin");
			}
			return UploadOrigin.from(uri);
		} catch (URISyntaxException exception) {
			throw new IllegalArgumentException("上传来源配置无效", exception);
		}
	}

	private record UploadOrigin(String scheme, String host, int port) {
		private static UploadOrigin from(URI uri) {
			String scheme = uri.getScheme() == null ? ""
				: uri.getScheme().toLowerCase(Locale.ROOT);
			String host = uri.getHost() == null ? ""
				: uri.getHost().toLowerCase(Locale.ROOT);
			if (!(scheme.equals("http") || scheme.equals("https"))
					|| host.isEmpty()) {
				throw new IllegalArgumentException("上传来源必须使用 HTTP(S)");
			}
			int port = uri.getPort();
			if (port < 0) {
				port = scheme.equals("https") ? 443 : 80;
			}
			return new UploadOrigin(scheme, host, port);
		}
	}

	private BusinessException invalidPhoto() {
		return new BusinessException(HttpStatus.BAD_REQUEST,
			"INVALID_DAILY_REPORT_PHOTO", "日报照片必须来自平台上传服务");
	}

	@Transactional(readOnly = true)
	public List<DailyReportResponse> findByBooking(UUID userId, UUID bookingId) {
		Booking booking = bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));
		if (!booking.getOwnerUserId().equals(userId)
				&& !booking.getWorkerUserId().equals(userId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在");
		}
		return reportRepository
			.findByBookingIdOrderByReportDateDescReportRevisionDesc(bookingId)
				.stream()
				.map(DailyReportResponse::from)
				.toList();
	}
}
