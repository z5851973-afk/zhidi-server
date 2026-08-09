package com.zhidi.server.inspection;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.infrastructure.storage.FileStorageService;
import com.zhidi.server.notification.BusinessEventDraft;
import com.zhidi.server.notification.BusinessEventPublisher;
import com.zhidi.server.notification.BusinessEventType;
import java.net.URI;
import java.time.LocalDate;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class InspectionService {

	private final InspectionNodeRepository nodeRepository;
	private final InspectionRecordRepository recordRepository;
	private final InspectionSubmissionRepository submissionRepository;
	private final InspectionEvidenceAssetRepository evidenceAssetRepository;
	private final BookingRepository bookingRepository;
	private final FileStorageService fileStorageService;
	private final BusinessEventPublisher businessEvents;
	private final Set<String> allowedPublicHosts;

	public InspectionService(InspectionNodeRepository nodeRepository,
			InspectionRecordRepository recordRepository,
			InspectionSubmissionRepository submissionRepository,
			InspectionEvidenceAssetRepository evidenceAssetRepository,
			BookingRepository bookingRepository,
			FileStorageService fileStorageService,
			BusinessEventPublisher businessEvents,
			@Value("${zhidi.upload.allowed-public-hosts:47.109.0.191,localhost,127.0.0.1}")
			String allowedPublicHosts) {
		this.nodeRepository = nodeRepository;
		this.recordRepository = recordRepository;
		this.submissionRepository = submissionRepository;
		this.evidenceAssetRepository = evidenceAssetRepository;
		this.bookingRepository = bookingRepository;
		this.fileStorageService = fileStorageService;
		this.businessEvents = businessEvents;
		this.allowedPublicHosts = Arrays.stream(allowedPublicHosts.split(","))
			.map(String::trim)
			.filter(value -> !value.isEmpty())
			.map(value -> value.toLowerCase(Locale.ROOT))
			.collect(Collectors.toUnmodifiableSet());
	}

	@Transactional
	public List<InspectionNodeResponse> createNodes(UUID workerUserId, UUID bookingId,
			List<CreateNodeRequest> requests) {
		Booking booking = bookingRepository.findByIdForUpdate(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));
		if (!booking.getWorkerUserId().equals(workerUserId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在");
		}

		if (booking.getStatus() != BookingStatus.HIRED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有已选定(HIRED)的预约才能创建施工节点");
		}
		if (requests == null || requests.isEmpty()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INSPECTION_NODES_REQUIRED", "至少需要一个验收节点");
		}

		Set<String> requestedNames = new HashSet<>();
		for (CreateNodeRequest request : requests) {
			String name = request.name().trim();
			if (!InspectionTradeMatcher.matchesName(name, booking.getTrade())) {
				throw new BusinessException(HttpStatus.BAD_REQUEST,
					"INSPECTION_NODE_TRADE_MISMATCH", "验收节点必须属于当前预约工种");
			}
			if (!requestedNames.add(name)
					|| nodeRepository.existsByBookingIdAndName(bookingId, name)) {
				throw new BusinessException(HttpStatus.CONFLICT,
					"DUPLICATE_INSPECTION_NODE", "同一预约不能创建重复验收节点");
			}
		}

		List<InspectionNode> nodes = requests.stream()
			.map(req -> InspectionNode.create(bookingId, req.name().trim(),
				req.description(), req.sortOrder()))
			.toList();

		return nodeRepository.saveAllAndFlush(nodes).stream()
			.map(InspectionNodeResponse::from)
			.toList();
	}

	@Transactional(readOnly = true)
	public List<InspectionNodeResponse> getNodes(UUID userId, UUID bookingId) {
		requireParticipant(userId, bookingId);
		return nodeRepository.findByBookingIdOrderBySortOrderAsc(bookingId)
			.stream()
			.map(InspectionNodeResponse::from)
			.toList();
	}

	@Transactional
	public InspectionNodeResponse requestInspection(UUID workerUserId, UUID nodeId) {
		return requestInspection(workerUserId, nodeId,
			InspectionSubmissionRequest.empty());
	}

	@Transactional
	public InspectionNodeResponse requestInspection(UUID workerUserId, UUID nodeId,
			InspectionSubmissionRequest request) {
		LockedInspectionContext context = lockInspectionContext(nodeId);
		InspectionNode node = context.node();
		Booking booking = context.booking();

		if (!booking.getWorkerUserId().equals(workerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_WORKER", "只有该预约的工人才能申请验收");
		}
		if (booking.getStatus() != BookingStatus.HIRED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有施工中的预约才能申请验收");
		}

		if (node.getStatus() != InspectionNodeStatus.PENDING
				&& node.getStatus() != InspectionNodeStatus.FAILED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_NODE_STATUS", "只有待验收或整改未通过的节点才能申请验收");
		}
		List<String> photos = validatePhotos(request.photos(), node, booking,
			workerUserId);
		int nextRound = submissionRepository
			.findByNodeIdOrderBySubmissionVersionAsc(nodeId).stream()
			.mapToInt(InspectionSubmission::getSubmissionVersion)
			.max().orElse(0) + 1;
		InspectionSubmission submission = InspectionSubmission.create(
			nodeId, workerUserId, normalizeText(request.note()), photos, nextRound);
		InspectionSubmission savedSubmission = submissionRepository
			.saveAndFlush(submission);

		node.requestInspection();
		InspectionNode savedNode = nodeRepository.save(node);
		businessEvents.publish(new BusinessEventDraft(
			booking.getOwnerUserId(),
			workerUserId,
			BusinessEventType.INSPECTION_REQUESTED,
			"INSPECTION_NODE",
			nodeId,
			booking.getId(),
			booking.getServiceRequestId(),
			"inspection-submission:" + savedSubmission.getId(),
			Map.of("round", savedSubmission.getSubmissionVersion()),
			savedSubmission.getCreatedAt()));
		return InspectionNodeResponse.from(savedNode);
	}

	@Transactional
	public InspectionRecordResponse inspect(UUID inspectorUserId, UUID nodeId,
			InspectRequest request) {
		LockedInspectionContext context = lockInspectionContext(nodeId);
		InspectionNode node = context.node();
		Booking booking = context.booking();

		if (!booking.getOwnerUserId().equals(inspectorUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_OWNER", "只有业主才能执行验收");
		}

		if (node.getStatus() != InspectionNodeStatus.INSPECTING) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_NODE_STATUS", "只有验收中的节点才能执行验收操作");
		}
		String comment = normalizeText(request.comment());
		if (request.result() == InspectionResult.FAIL && comment == null) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"RECTIFICATION_COMMENT_REQUIRED", "验收不通过时必须填写整改意见");
		}
		List<String> photos = validatePhotos(request.photos(), node, booking,
			inspectorUserId);

		int submissionRound = submissionRepository
			.findByNodeIdOrderBySubmissionVersionAsc(nodeId).stream()
			.mapToInt(InspectionSubmission::getSubmissionVersion)
			.max().orElse(0);
		int nextVersion = recordRepository
			.findByNodeIdOrderByInspectionVersionDesc(nodeId).stream()
			.findFirst().map(record -> record.getInspectionVersion() + 1).orElse(1);
		if (submissionRound != nextVersion) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INSPECTION_ROUND_MISMATCH", "验收轮次与工人提交记录不一致");
		}

		InspectionRecord record = InspectionRecord.create(nodeId, inspectorUserId,
			request.result(), comment, photos, nextVersion);
		InspectionRecord saved = recordRepository.saveAndFlush(record);

		if (request.result() == InspectionResult.PASS) {
			node.markPassed();
		} else {
			node.markFailed();
		}
		nodeRepository.saveAndFlush(node);

		if (request.result() == InspectionResult.PASS) {
			List<InspectionNode> currentTradeNodes = nodeRepository
				.findByBookingIdForUpdate(booking.getId())
				.stream()
				.filter(candidate -> InspectionTradeMatcher.matches(
					candidate, booking.getTrade()))
				.toList();
			if (!currentTradeNodes.isEmpty() && currentTradeNodes.stream()
					.allMatch(candidate ->
						candidate.getStatus() == InspectionNodeStatus.PASSED)) {
				booking.markCompleted();
				bookingRepository.save(booking);
			}
		}

		BusinessEventType eventType = request.result() == InspectionResult.PASS
			? BusinessEventType.INSPECTION_PASSED
			: BusinessEventType.INSPECTION_RECTIFICATION_REQUIRED;
		businessEvents.publish(new BusinessEventDraft(
			booking.getWorkerUserId(),
			inspectorUserId,
			eventType,
			"INSPECTION_NODE",
			nodeId,
			booking.getId(),
			booking.getServiceRequestId(),
			"inspection-record:" + saved.getId(),
			Map.of(
				"round", saved.getInspectionVersion(),
				"result", saved.getResult().name()),
			saved.getCreatedAt()));

		return InspectionRecordResponse.from(saved);
	}

	@Transactional
	public InspectionEvidenceUploadResponse uploadEvidence(UUID uploaderUserId,
			UUID nodeId, MultipartFile file) {
		InspectionNode node = nodeRepository.findById(nodeId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"NODE_NOT_FOUND", "施工节点不存在"));
		Booking booking = bookingRepository.findById(node.getBookingId())
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));
		if (!booking.getOwnerUserId().equals(uploaderUserId)
				&& !booking.getWorkerUserId().equals(uploaderUserId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在");
		}
		validateNodeTrade(node, booking);
		if (booking.getStatus() != BookingStatus.HIRED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有施工中的预约才能上传验收证据");
		}
		if (file == null || file.isEmpty()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"EMPTY_INSPECTION_EVIDENCE", "验收照片不能为空");
		}
		if (file.getSize() > 10 * 1024 * 1024) {
			throw new BusinessException(HttpStatus.PAYLOAD_TOO_LARGE,
				"INSPECTION_EVIDENCE_TOO_LARGE", "验收照片不能超过 10MB");
		}
		String extension = switch (String.valueOf(file.getContentType())) {
			case "image/jpeg" -> ".jpg";
			case "image/png" -> ".png";
			case "image/webp" -> ".webp";
			default -> throw new BusinessException(HttpStatus.UNSUPPORTED_MEDIA_TYPE,
				"INVALID_INSPECTION_EVIDENCE_TYPE", "仅支持 JPG、PNG、WEBP 图片");
		};
		String objectKey = "inspection-evidence/" + booking.getId() + "/"
			+ nodeId + "/" + uploaderUserId + "/"
			+ LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd"))
			+ "/" + UUID.randomUUID() + extension;
		byte[] bytes;
		try {
			bytes = file.getBytes();
		} catch (Exception exception) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_INSPECTION_EVIDENCE", "无法读取验收照片");
		}
		String url = fileStorageService.upload(objectKey, bytes,
			file.getContentType());
		evidenceAssetRepository.saveAndFlush(InspectionEvidenceAsset.create(
			booking.getId(), nodeId, uploaderUserId, url, objectKey));
		return new InspectionEvidenceUploadResponse(url, objectKey);
	}

	@Transactional(readOnly = true)
	public List<InspectionRecordResponse> getRecords(UUID userId, UUID nodeId) {
		InspectionNode node = nodeRepository.findById(nodeId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"NODE_NOT_FOUND", "施工节点不存在"));
		requireParticipant(userId, node.getBookingId());
		return recordRepository.findByNodeIdOrderByInspectionVersionDesc(nodeId)
			.stream()
			.map(InspectionRecordResponse::from)
			.toList();
	}

	@Transactional(readOnly = true)
	public List<InspectionTimelineResponse> getTimeline(UUID userId, UUID nodeId) {
		InspectionNode node = nodeRepository.findById(nodeId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"NODE_NOT_FOUND", "施工节点不存在"));
		requireParticipant(userId, node.getBookingId());
		List<InspectionTimelineResponse> timeline = new ArrayList<>();
		timeline.addAll(submissionRepository
			.findByNodeIdOrderBySubmissionVersionAsc(nodeId).stream()
			.map(InspectionTimelineResponse::from).toList());
		timeline.addAll(recordRepository
			.findByNodeIdOrderByInspectionVersionDesc(nodeId).stream()
			.map(InspectionTimelineResponse::from).toList());
		timeline.sort((left, right) -> {
			Instant leftAt = left.createdAt();
			Instant rightAt = right.createdAt();
			int timeOrder = leftAt.compareTo(rightAt);
			if (timeOrder != 0) return timeOrder;
			int roundOrder = Integer.compare(left.round(), right.round());
			if (roundOrder != 0) return roundOrder;
			return left.type().equals("WORKER_SUBMISSION") ? -1 : 1;
		});
		return List.copyOf(timeline);
	}

	private List<String> validatePhotos(List<String> rawPhotos,
			InspectionNode node, Booking booking, UUID uploaderUserId) {
		List<String> photos = rawPhotos == null ? List.of() : rawPhotos.stream()
			.map(String::trim).filter(value -> !value.isEmpty()).toList();
		if (photos.size() > 9) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"TOO_MANY_INSPECTION_PHOTOS", "验收照片最多 9 张");
		}
		if (new HashSet<>(photos).size() != photos.size()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_INSPECTION_PHOTO", "验收照片不能重复");
		}
		if (photos.isEmpty()) return List.of();
		Set<String> lookupUrls = new HashSet<>(photos);
		Map<String, String> absoluteUrlPaths = new HashMap<>();
		for (String photo : photos) {
			String relativePath = trustedRelativePath(photo);
			if (relativePath != null) absoluteUrlPaths.put(photo, relativePath);
		}
		lookupUrls.addAll(absoluteUrlPaths.values());
		Map<String, InspectionEvidenceAsset> assets = evidenceAssetRepository
			.findByPublicUrlIn(lookupUrls).stream()
			.collect(Collectors.toMap(InspectionEvidenceAsset::getPublicUrl,
				Function.identity()));
		List<String> canonicalPhotos = new ArrayList<>(photos.size());
		Set<UUID> assetIds = new HashSet<>();
		for (String photo : photos) {
			InspectionEvidenceAsset asset = assets.get(photo);
			if (asset == null) {
				asset = assets.get(absoluteUrlPaths.get(photo));
			}
			if (asset == null || !asset.getBookingId().equals(booking.getId())
					|| !asset.getNodeId().equals(node.getId())
					|| !asset.getUploaderUserId().equals(uploaderUserId)
					|| !assetIds.add(asset.getId())) {
				throw invalidPhoto();
			}
			canonicalPhotos.add(asset.getPublicUrl());
		}
		return List.copyOf(canonicalPhotos);
	}

	private String trustedRelativePath(String rawUrl) {
		try {
			URI uri = URI.create(rawUrl).normalize();
			if (!uri.isAbsolute()
					|| !("http".equalsIgnoreCase(uri.getScheme())
						|| "https".equalsIgnoreCase(uri.getScheme()))
					|| uri.getHost() == null
					|| !allowedPublicHosts.contains(
						uri.getHost().toLowerCase(Locale.ROOT))
					|| uri.getUserInfo() != null
					|| uri.getRawQuery() != null
					|| uri.getRawFragment() != null) {
				return null;
			}
			String path = uri.getRawPath();
			return path != null
				&& path.startsWith("/uploads/inspection-evidence/")
				? path : null;
		} catch (IllegalArgumentException ignored) {
			return null;
		}
	}

	private BusinessException invalidPhoto() {
		return new BusinessException(HttpStatus.BAD_REQUEST,
			"INVALID_INSPECTION_PHOTO", "验收照片必须来自平台验收证据上传目录");
	}

	private String normalizeText(String value) {
		if (value == null || value.trim().isEmpty()) return null;
		return value.trim();
	}

	private LockedInspectionContext lockInspectionContext(UUID nodeId) {
		UUID bookingId = nodeRepository.findBookingIdById(nodeId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"NODE_NOT_FOUND", "施工节点不存在"));
		Booking booking = bookingRepository.findByIdForUpdate(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));
		InspectionNode node = nodeRepository.findByIdForUpdate(nodeId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"NODE_NOT_FOUND", "施工节点不存在"));
		if (!node.getBookingId().equals(booking.getId())) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INSPECTION_CONTEXT_CHANGED", "验收节点上下文已变化，请重试");
		}
		validateNodeTrade(node, booking);
		return new LockedInspectionContext(node, booking);
	}

	private void validateNodeTrade(InspectionNode node, Booking booking) {
		if (!InspectionTradeMatcher.matches(node, booking.getTrade())) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INSPECTION_NODE_TRADE_MISMATCH", "验收节点必须属于当前预约工种");
		}
	}

	private record LockedInspectionContext(InspectionNode node, Booking booking) {}

	private Booking requireParticipant(UUID userId, UUID bookingId) {
		Booking booking = bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));
		if (!booking.getOwnerUserId().equals(userId)
				&& !booking.getWorkerUserId().equals(userId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在");
		}
		return booking;
	}
}
