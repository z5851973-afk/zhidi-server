package com.zhidi.server.payment;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.infrastructure.storage.TencentCosProperties;
import com.zhidi.server.inspection.InspectionNode;
import com.zhidi.server.inspection.InspectionNodeRepository;
import com.zhidi.server.inspection.InspectionNodeStatus;
import com.zhidi.server.inspection.InspectionTradeMatcher;
import com.zhidi.server.notification.BusinessEventDraft;
import com.zhidi.server.notification.BusinessEventPublisher;
import com.zhidi.server.notification.BusinessEventType;
import java.math.BigDecimal;
import java.net.URI;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AfterSaleService {
	private static final List<AfterSaleStatus> ACTIVE_STATUSES = List.of(
		AfterSaleStatus.OPEN, AfterSaleStatus.PLATFORM_PROCESSING);
	private static final int MAX_EVIDENCE_COUNT = 9;
	private static final int MAX_EVIDENCE_URL_LENGTH = 2048;
	private static final Pattern EVIDENCE_OBJECT_PATH = Pattern.compile(
		"^/(?:uploads/)?after-sales/[A-Za-z0-9/_-]+\\.(?:jpg|jpeg|png|webp)$",
		Pattern.CASE_INSENSITIVE);

	private final AfterSaleRepository afterSales;
	private final AfterSaleEventRepository events;
	private final BookingRepository bookings;
	private final WarrantyRetentionRepository warrantyRetentions;
	private final PaymentOrderRepository paymentOrders;
	private final WorkerWarrantyAccountService workerWarrantyAccounts;
	private final InspectionNodeRepository inspectionNodes;
	private final BusinessEventPublisher businessEvents;
	private final String allowedCosHost;

	public AfterSaleService(AfterSaleRepository afterSales,
			AfterSaleEventRepository events, BookingRepository bookings,
			WarrantyRetentionRepository warrantyRetentions,
			PaymentOrderRepository paymentOrders,
			WorkerWarrantyAccountService workerWarrantyAccounts,
			InspectionNodeRepository inspectionNodes,
			BusinessEventPublisher businessEvents,
			TencentCosProperties cosProperties) {
		this.afterSales = afterSales;
		this.events = events;
		this.bookings = bookings;
		this.warrantyRetentions = warrantyRetentions;
		this.paymentOrders = paymentOrders;
		this.workerWarrantyAccounts = workerWarrantyAccounts;
		this.inspectionNodes = inspectionNodes;
		this.businessEvents = businessEvents;
		this.allowedCosHost = configuredCosHost(cosProperties);
	}

	@Transactional
	public AfterSaleResponse create(UUID bookingId, UUID ownerUserId,
			AfterSaleType type, String reason, List<String> evidenceUrls) {
		Booking booking = requireEligibleBooking(bookingId, ownerUserId);
		validateText(reason, "REASON_REQUIRED", "售后原因不能为空");
		List<String> evidence = validateEvidence(evidenceUrls);
		if (afterSales.existsByBookingIdAndStatusIn(bookingId, ACTIVE_STATUSES)) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_ALREADY_OPEN", "该订单已有处理中的售后工单");
		}

		AfterSale afterSale = AfterSale.create(bookingId, ownerUserId,
			booking.getWorkerUserId(), type, reason.trim(), evidence);
		try {
			afterSale = afterSales.saveAndFlush(afterSale);
		} catch (DataIntegrityViolationException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_ALREADY_OPEN", "该订单已有处理中的售后工单");
		}
		AfterSaleEvent event = events.saveAndFlush(AfterSaleEvent.create(
			afterSale.getId(), ownerUserId,
			AfterSaleActorRole.OWNER, AfterSaleEventType.CREATED,
			afterSale.getReason(), evidence, "created:" + afterSale.getId()));
		publishToParticipants(afterSale, event, booking);
		return AfterSaleResponse.from(afterSale);
	}

	@Transactional(readOnly = true)
	public AfterSaleDetailResponse getAfterSale(UUID userId, UUID afterSaleId) {
		AfterSale afterSale = requireParticipantTicket(userId, afterSaleId);
		Booking booking = bookings.findById(afterSale.getBookingId())
			.orElseThrow(this::notFound);
		AfterSaleDetailResponse.OrderContext context =
			buildOrderContext(afterSale.getBookingId(), booking);
		List<AfterSaleEventResponse> timeline = events
			.findByAfterSaleIdOrderByCreatedAtAscIdAsc(afterSaleId)
			.stream().map(AfterSaleEventResponse::from).toList();
		return new AfterSaleDetailResponse(AfterSaleResponse.from(afterSale),
			context, timeline);
	}

	@Transactional(readOnly = true)
	public AfterSaleDetailResponse.OrderContext getBookingContext(UUID ownerUserId,
			UUID bookingId) {
		Booking booking = bookings.findById(bookingId).orElseThrow(() ->
			new BusinessException(HttpStatus.NOT_FOUND,
				"AFTER_SALE_CONTEXT_NOT_FOUND", "订单不存在"));
		if (!Objects.equals(booking.getOwnerUserId(), ownerUserId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"AFTER_SALE_CONTEXT_NOT_FOUND", "订单不存在");
		}
		return buildOrderContext(bookingId, booking);
	}

	@Transactional(readOnly = true)
	public List<AfterSaleResponse> listForUser(UUID userId) {
		return afterSales.findForParticipant(userId)
			.stream().map(AfterSaleResponse::from).toList();
	}

	@Transactional(readOnly = true)
	public Page<AfterSaleResponse> listForAdmin(Pageable pageable,
			AfterSaleStatus status) {
		Page<AfterSale> page = status == null
			? afterSales.findAll(pageable)
			: afterSales.findByStatus(status, pageable);
		return page.map(AfterSaleResponse::from);
	}

	@Transactional
	public AfterSaleEventResponse appendParticipantEvent(UUID userId,
			UUID afterSaleId, String content, List<String> evidenceUrls,
			String idempotencyKey) {
		AfterSale afterSale = requireParticipantTicket(userId, afterSaleId);
		String key = normalizedKey(idempotencyKey);
		AfterSaleEvent existing = events
			.findByAfterSaleIdAndIdempotencyKey(afterSaleId, key).orElse(null);
		if (existing != null) {
			return AfterSaleEventResponse.from(existing);
		}
		if (afterSale.getStatus() == AfterSaleStatus.RESOLVED
				|| afterSale.getStatus() == AfterSaleStatus.CLOSED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_NOT_ACTIVE", "当前售后工单不能再追加内容");
		}
		List<String> evidence = validateEvidence(evidenceUrls);
		if ((content == null || content.isBlank()) && evidence.isEmpty()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"AFTER_SALE_EVENT_EMPTY", "请输入说明或上传证据");
		}
		AfterSaleActorRole role = Objects.equals(afterSale.getOwnerUserId(), userId)
			? AfterSaleActorRole.OWNER : AfterSaleActorRole.WORKER;
		AfterSaleEvent event = AfterSaleEvent.create(afterSaleId, userId, role,
			AfterSaleEventType.PARTICIPANT_MESSAGE, content, evidence, key);
		try {
			event = events.saveAndFlush(event);
		} catch (DataIntegrityViolationException ex) {
			return events.findByAfterSaleIdAndIdempotencyKey(afterSaleId, key)
				.map(AfterSaleEventResponse::from).orElseThrow(() -> ex);
		}
		afterSale.touch();
		afterSales.saveAndFlush(afterSale);
		publishToCounterparty(afterSale, event, userId);
		return AfterSaleEventResponse.from(event);
	}

	@Transactional
	public AfterSaleResponse adminAccept(UUID adminUserId, UUID afterSaleId) {
		AfterSale afterSale = requireTicket(afterSaleId);
		try {
			afterSale.markPlatformProcessing();
		} catch (IllegalStateException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_INVALID_STATUS", ex.getMessage());
		}
		afterSales.saveAndFlush(afterSale);
		AfterSaleEvent event = events.saveAndFlush(AfterSaleEvent.create(
			afterSaleId, adminUserId,
			AfterSaleActorRole.ADMIN, AfterSaleEventType.PLATFORM_ACCEPTED,
			"平台已受理", List.of(), "accept:" + afterSaleId));
		publishToParticipants(afterSale, event);
		return AfterSaleResponse.from(afterSale);
	}

	@Transactional
	public AfterSaleEventResponse appendAdminReply(UUID adminUserId,
			UUID afterSaleId, String content, List<String> evidenceUrls) {
		AfterSale afterSale = requireTicket(afterSaleId);
		if (afterSale.getStatus() != AfterSaleStatus.PLATFORM_PROCESSING) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_NOT_ACCEPTED", "平台受理后才能回复售后工单");
		}
		List<String> evidence = validateEvidence(evidenceUrls);
		if ((content == null || content.isBlank()) && evidence.isEmpty()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"AFTER_SALE_EVENT_EMPTY", "请输入回复或上传证据");
		}
		AfterSaleEvent event = events.saveAndFlush(AfterSaleEvent.create(afterSaleId,
			adminUserId, AfterSaleActorRole.ADMIN, AfterSaleEventType.PLATFORM_REPLY,
			content, evidence, "admin-reply:" + UUID.randomUUID()));
		afterSale.touch();
		afterSales.saveAndFlush(afterSale);
		publishToParticipants(afterSale, event);
		return AfterSaleEventResponse.from(event);
	}

	@Transactional
	public AfterSaleResponse adminResolve(UUID adminUserId, UUID afterSaleId,
			String resolution, BigDecimal warrantyDeductionAmount) {
		return resolveInternal(adminUserId, afterSaleId, resolution,
			warrantyDeductionAmount);
	}

	@Transactional
	public AfterSaleResponse process(UUID afterSaleId, String resolution) {
		return process(afterSaleId, resolution, null);
	}

	@Transactional
	public AfterSaleResponse process(UUID afterSaleId, String resolution,
			BigDecimal warrantyDeductionAmount) {
		return resolveInternal(null, afterSaleId, resolution,
			warrantyDeductionAmount);
	}

	@Transactional
	public AfterSaleResponse adminClose(UUID adminUserId, UUID afterSaleId,
			String content) {
		AfterSale afterSale = requireTicket(afterSaleId);
		try {
			afterSale.close();
		} catch (IllegalStateException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_INVALID_STATUS", ex.getMessage());
		}
		afterSales.saveAndFlush(afterSale);
		AfterSaleEvent event = events.saveAndFlush(AfterSaleEvent.create(
			afterSaleId, adminUserId,
			AfterSaleActorRole.ADMIN, AfterSaleEventType.CLOSED,
			content == null || content.isBlank() ? "售后工单已关闭" : content,
			List.of(), "close:" + afterSaleId));
		publishToParticipants(afterSale, event);
		return AfterSaleResponse.from(afterSale);
	}

	private AfterSaleResponse resolveInternal(UUID adminUserId, UUID afterSaleId,
			String resolution, BigDecimal warrantyDeductionAmount) {
		AfterSale afterSale = requireTicket(afterSaleId);
		if (afterSale.getStatus() != AfterSaleStatus.PLATFORM_PROCESSING) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_NOT_ACCEPTED", "平台受理后才能解决售后工单");
		}
		validateText(resolution, "RESOLUTION_REQUIRED", "处理方案不能为空");

		if (warrantyDeductionAmount != null
				&& warrantyDeductionAmount.compareTo(BigDecimal.ZERO) > 0) {
			PaymentOrder paymentOrder = paymentOrders
				.findByBookingId(afterSale.getBookingId()).orElse(null);
			if (paymentOrder != null && paymentOrder.getFundingModel()
					== PaymentFundingModel.OFFLINE_SPLIT_V2) {
				workerWarrantyAccounts.deductForAfterSale(
					paymentOrder.getWorkerUserId(), afterSaleId,
					warrantyDeductionAmount, resolution.trim());
				afterSale.processWithWarrantyDeduction(
					resolution.trim(), warrantyDeductionAmount.setScale(2));
			} else {
				WarrantyRetention retention = warrantyRetentions
					.findFirstByBookingIdOrderByCreatedAtDesc(afterSale.getBookingId())
					.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
						"WARRANTY_RETENTION_NOT_FOUND", "该售后工单没有可扣减的质保金"));
				try {
					retention.deduct(warrantyDeductionAmount, resolution.trim());
				} catch (IllegalArgumentException ex) {
					throw new BusinessException(HttpStatus.BAD_REQUEST,
						"INVALID_DEDUCTION_AMOUNT", ex.getMessage());
				} catch (IllegalStateException ex) {
					throw new BusinessException(HttpStatus.CONFLICT,
						"INVALID_STATUS", ex.getMessage());
				}
				warrantyRetentions.saveAndFlush(retention);
				afterSale.process(resolution.trim(), retention.getId(),
					warrantyDeductionAmount.setScale(2));
			}
		} else {
			afterSale.process(resolution.trim());
		}
		afterSales.saveAndFlush(afterSale);
		AfterSaleEvent event = events.saveAndFlush(AfterSaleEvent.create(
			afterSaleId, adminUserId,
			AfterSaleActorRole.ADMIN, AfterSaleEventType.RESOLVED,
			resolution.trim(), List.of(), "resolve:" + afterSaleId));
		publishToParticipants(afterSale, event);
		return AfterSaleResponse.from(afterSale);
	}

	private void publishToParticipants(AfterSale afterSale,
			AfterSaleEvent event) {
		Booking booking = bookings.findById(afterSale.getBookingId())
			.orElseThrow(this::notFound);
		publishToParticipants(afterSale, event, booking);
	}

	private void publishToParticipants(AfterSale afterSale,
			AfterSaleEvent event, Booking booking) {
		publish(afterSale, event, booking,
			List.of(afterSale.getOwnerUserId(), afterSale.getWorkerUserId()));
	}

	private void publishToCounterparty(AfterSale afterSale,
			AfterSaleEvent event, UUID actorUserId) {
		Booking booking = bookings.findById(afterSale.getBookingId())
			.orElseThrow(this::notFound);
		UUID recipientUserId = Objects.equals(
			afterSale.getOwnerUserId(), actorUserId)
			? afterSale.getWorkerUserId()
			: afterSale.getOwnerUserId();
		publish(afterSale, event, booking, List.of(recipientUserId));
	}

	private void publish(AfterSale afterSale, AfterSaleEvent event,
			Booking booking, List<UUID> recipientUserIds) {
		List<BusinessEventDraft> drafts = recipientUserIds.stream()
			.map(recipientUserId -> new BusinessEventDraft(
				recipientUserId,
				event.getActorUserId(),
				businessEventType(event.getType()),
				"AFTER_SALE",
				afterSale.getId(),
				afterSale.getBookingId(),
				booking.getServiceRequestId(),
				"after-sale-event:" + event.getId(),
				Map.of("afterSaleEventType", event.getType().name()),
				event.getCreatedAt()))
			.toList();
		businessEvents.publish(drafts);
	}

	private static BusinessEventType businessEventType(AfterSaleEventType type) {
		return switch (type) {
			case CREATED -> BusinessEventType.AFTER_SALE_CREATED;
			case PARTICIPANT_MESSAGE ->
				BusinessEventType.AFTER_SALE_PARTICIPANT_MESSAGE;
			case PLATFORM_ACCEPTED ->
				BusinessEventType.AFTER_SALE_PLATFORM_ACCEPTED;
			case PLATFORM_REPLY ->
				BusinessEventType.AFTER_SALE_PLATFORM_REPLIED;
			case RESOLVED -> BusinessEventType.AFTER_SALE_RESOLVED;
			case CLOSED -> BusinessEventType.AFTER_SALE_CLOSED;
		};
	}

	private Booking requireEligibleBooking(UUID bookingId, UUID ownerUserId) {
		Booking booking = bookings.findById(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));
		if (!booking.getOwnerUserId().equals(ownerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_OWNER", "只有业主才能创建售后申请");
		}
		if (booking.getWorkerUserId() == null
				|| booking.getStatus() != BookingStatus.COMPLETED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_NOT_AVAILABLE", "仅已完工且已选定师傅的订单可申请售后");
		}
		PaymentOrder payment = paymentOrders.findByBookingId(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_PAYMENT_REQUIRED", "付款完成后才能申请售后"));
		if (payment.getStatus() != PaymentOrderStatus.PAID) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"AFTER_SALE_PAYMENT_REQUIRED", "付款完成后才能申请售后");
		}
		return booking;
	}

	private AfterSale requireParticipantTicket(UUID userId, UUID afterSaleId) {
		AfterSale afterSale = requireTicket(afterSaleId);
		if (!Objects.equals(afterSale.getOwnerUserId(), userId)
				&& !Objects.equals(afterSale.getWorkerUserId(), userId)) {
			throw notFound();
		}
		return afterSale;
	}

	private AfterSale requireTicket(UUID afterSaleId) {
		return afterSales.findById(afterSaleId).orElseThrow(this::notFound);
	}

	private BusinessException notFound() {
		return new BusinessException(HttpStatus.NOT_FOUND,
			"AFTER_SALE_NOT_FOUND", "售后工单不存在");
	}

	private static void validateText(String value, String code, String message) {
		if (value == null || value.isBlank()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST, code, message);
		}
	}

	private static String normalizedKey(String value) {
		if (value == null || value.isBlank() || value.trim().length() > 128) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_IDEMPOTENCY_KEY", "幂等键不能为空且不能超过 128 字符");
		}
		return value.trim();
	}

	private List<String> validateEvidence(List<String> evidenceUrls) {
		if (evidenceUrls == null) {
			return List.of();
		}
		List<String> normalized = evidenceUrls.stream()
			.filter(Objects::nonNull).map(String::trim)
			.filter(value -> !value.isEmpty()).distinct().toList();
		if (normalized.size() > MAX_EVIDENCE_COUNT) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"TOO_MANY_EVIDENCE_FILES", "每次最多上传 9 张图片");
		}
		if (normalized.stream().anyMatch(value -> !isValidEvidenceUrl(value))) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_EVIDENCE_URL", "证据图片地址非法");
		}
		return normalized;
	}

	private AfterSaleDetailResponse.OrderContext buildOrderContext(UUID bookingId,
			Booking booking) {
		PaymentOrder payment = paymentOrders.findByBookingId(bookingId).orElse(null);
		List<InspectionNode> nodes = inspectionNodes
			.findByBookingIdOrderBySortOrderAsc(bookingId).stream()
			.filter(node -> InspectionTradeMatcher.matches(node, booking.getTrade()))
			.toList();
		return new AfterSaleDetailResponse.OrderContext(
			bookingId,
			booking.getStatus() == null ? null : booking.getStatus().name(),
			booking.getTrade(), booking.getOwnerName(),
			booking.getWorkerName(), booking.getServiceCity(),
			booking.getServiceAddress(), payment == null ? null : payment.getQuoteId(),
			payment == null ? null : payment.getQuoteAmount(),
			payment == null ? null : payment.getId(),
			payment == null ? null : payment.getAmount(),
			payment == null ? null : payment.getStatus().name(),
			inspectionSummary(nodes));
	}

	private boolean isValidEvidenceUrl(String value) {
		if (value.length() > MAX_EVIDENCE_URL_LENGTH || value.indexOf('\\') >= 0) {
			return false;
		}
		try {
			URI uri = URI.create(value);
			if (uri.getRawQuery() != null || uri.getRawFragment() != null
					|| uri.getUserInfo() != null || uri.getPort() != -1) {
				return false;
			}
			String path = uri.getPath();
			String rawPath = uri.getRawPath();
			if (path == null || rawPath == null || !rawPath.equals(path)
					|| !uri.normalize().getPath().equals(path)
					|| !EVIDENCE_OBJECT_PATH.matcher(path).matches()) {
				return false;
			}
			if (!uri.isAbsolute()) {
				return uri.getHost() == null
					&& path.startsWith("/uploads/after-sales/");
			}
			String host = uri.getHost();
			return "https".equalsIgnoreCase(uri.getScheme())
				&& host != null
				&& host.toLowerCase(Locale.ROOT).equals(allowedCosHost)
				&& path.startsWith("/after-sales/");
		} catch (IllegalArgumentException ex) {
			return false;
		}
	}

	private static String configuredCosHost(TencentCosProperties properties) {
		if (properties == null || properties.bucket() == null
				|| properties.bucket().isBlank() || properties.region() == null
				|| properties.region().isBlank()) {
			return "";
		}
		return (properties.bucket().trim() + ".cos."
			+ properties.region().trim() + ".myqcloud.com")
			.toLowerCase(Locale.ROOT);
	}

	private static AfterSaleDetailResponse.InspectionSummary inspectionSummary(
			List<InspectionNode> nodes) {
		List<InspectionNode> safeNodes = nodes == null ? List.of() : nodes;
		int passed = (int) safeNodes.stream()
			.filter(node -> node.getStatus() == InspectionNodeStatus.PASSED).count();
		String status;
		if (safeNodes.isEmpty()) {
			status = "NOT_AVAILABLE";
		} else if (passed == safeNodes.size()) {
			status = "PASSED";
		} else if (safeNodes.stream()
				.anyMatch(node -> node.getStatus() == InspectionNodeStatus.FAILED)) {
			status = "FAILED";
		} else if (safeNodes.stream()
				.anyMatch(node -> node.getStatus() == InspectionNodeStatus.INSPECTING)) {
			status = "INSPECTING";
		} else {
			status = "PENDING";
		}
		return new AfterSaleDetailResponse.InspectionSummary(status, passed,
			safeNodes.size());
	}
}
