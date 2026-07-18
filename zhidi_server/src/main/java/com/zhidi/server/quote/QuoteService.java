package com.zhidi.server.quote;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class QuoteService {

	private final QuoteRepository quotes;
	private final BookingRepository bookings;
	private final ServiceCatalogRepository catalogs;
	private final ServiceRequestRepository serviceRequests;

	public QuoteService(QuoteRepository quotes, BookingRepository bookings,
			ServiceCatalogRepository catalogs,
			ServiceRequestRepository serviceRequests) {
		this.quotes = quotes;
		this.bookings = bookings;
		this.catalogs = catalogs;
		this.serviceRequests = serviceRequests;
	}

	@Transactional
	public QuoteResponse submit(UUID workerUserId, UUID bookingId,
			QuoteRequest request) {
		Booking booking = bookings.findByIdAndWorkerUserId(bookingId, workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));

		if (booking.getStatus() != BookingStatus.ON_SITE) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有到场后才能提交报价");
		}

		Set<String> categories = resolveCategories(booking.getTrade());
		Map<String, ServiceCatalog> catalogByName = catalogs
			.findByCategoryInOrderBySortOrderAsc(categories)
			.stream()
			.collect(Collectors.toMap(
				ServiceCatalog::getName, Function.identity(),
				(existing, duplicate) -> existing));

		List<QuoteItem> items = request.items().stream().map(reqItem -> {
			ServiceCatalog catalog = catalogByName.get(reqItem.name());
			if (catalog == null) {
				throw new BusinessException(HttpStatus.BAD_REQUEST,
					"ITEM_NOT_IN_CATALOG",
					"项目「" + reqItem.name() + "」不在工种价格目录中");
			}
			if (reqItem.unitPrice() != null) {
				if (reqItem.unitPrice().compareTo(catalog.getUnitPrice()) != 0) {
					throw new BusinessException(HttpStatus.BAD_REQUEST,
						"PRICE_MISMATCH",
						"「" + reqItem.name() + "」单价与目录不一致，目录价: " +
							catalog.getUnitPrice());
				}
			}
			return QuoteItem.fromCatalog(catalog, reqItem.quantity());
		}).toList();

		Quote quote = Quote.create(booking.getId(), workerUserId, items);
		Quote saved = quotes.saveAndFlush(quote);

		booking.submitQuote();
		bookings.save(booking);

		return toResponse(saved);
	}

	@Transactional(readOnly = true)
	public List<QuoteResponse> listForBooking(UUID bookingId) {
		return quotes.findByBookingIdOrderByCreatedAtDesc(bookingId)
			.stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public List<QuoteResponse> listForWorker(UUID workerUserId) {
		return quotes.findByWorkerUserIdOrderByCreatedAtDesc(workerUserId)
			.stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public List<ServiceCatalogResponse> getCatalog(String category) {
		if (category == null || category.isBlank()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"CATEGORY_REQUIRED", "category 参数不能为空");
		}
		Set<String> categories = resolveCategories(category);
		return catalogs.findByCategoryInOrderBySortOrderAsc(categories).stream()
			.map(ServiceCatalogResponse::fromEntity).toList();
	}

	@Transactional
	public QuoteResponse acceptQuote(UUID ownerUserId, UUID quoteId) {
		Quote quote = quotes.findById(quoteId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"QUOTE_NOT_FOUND", "报价不存在"));

		if (quote.getStatus() != QuoteStatus.SUBMITTED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_QUOTE_STATUS", "只有已提交的报价才能接受");
		}

		Booking targetBooking = bookings.findById(quote.getBookingId())
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));

		if (!targetBooking.getOwnerUserId().equals(ownerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_OWNER", "只有业主才能接受报价");
		}

		UUID requestId = targetBooking.getServiceRequestId();

		// 接受报价
		quote.accept();
		quotes.save(quote);

		// 目标预约 → HIRED
		targetBooking.hire();
		bookings.save(targetBooking);

		// 同一需求下其他活动候选 → NOT_SELECTED，其报价 → REJECTED
		List<Booking> candidates = bookings
			.findByServiceRequestIdOrderByCreatedAtAsc(requestId);
		for (Booking other : candidates) {
			if (other.getId().equals(targetBooking.getId())) {
				continue;
			}
			if (other.getStatus() != BookingStatus.CANCELLED
					&& other.getStatus() != BookingStatus.REJECTED
					&& other.getStatus() != BookingStatus.NOT_SELECTED
					&& other.getStatus() != BookingStatus.HIRED) {
				other.notSelect();
				bookings.save(other);

				// 关闭该候选的待处理报价
				List<Quote> otherQuotes = quotes
					.findByBookingIdOrderByCreatedAtDesc(other.getId());
				for (Quote otherQuote : otherQuotes) {
					if (otherQuote.getStatus() == QuoteStatus.SUBMITTED) {
						otherQuote.reject("其他工人已被选中");
						quotes.save(otherQuote);
					}
				}
			}
		}

		// 需求状态 → ASSIGNED
		serviceRequests.findById(requestId).ifPresent(ServiceRequest::markAssigned);

		return toResponse(quote);
	}

	@Transactional
	public QuoteResponse rejectQuote(UUID ownerUserId, UUID quoteId,
			String reason) {
		Quote quote = quotes.findById(quoteId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"QUOTE_NOT_FOUND", "报价不存在"));

		if (quote.getStatus() != QuoteStatus.SUBMITTED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_QUOTE_STATUS", "只有已提交的报价才能拒绝");
		}

		Booking booking = bookings.findById(quote.getBookingId())
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));

		if (!booking.getOwnerUserId().equals(ownerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_OWNER", "只有业主才能拒绝报价");
		}

		if (reason == null || reason.isBlank()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"REASON_REQUIRED", "拒绝原因不能为空");
		}

		quote.reject(reason.trim());
		quotes.save(quote);

		// booking 回退到 ON_SITE，工人可重新报价
		booking.reopenForQuote();
		bookings.save(booking);

		return toResponse(quote);
	}

	@Transactional(readOnly = true)
	public List<QuoteResponse> listQuotesForServiceRequest(UUID serviceRequestId) {
		List<Booking> bookingsForRequest = bookings
			.findByServiceRequestIdOrderByCreatedAtAsc(serviceRequestId);
		List<UUID> bookingIds = bookingsForRequest.stream()
			.map(Booking::getId).toList();

		if (bookingIds.isEmpty()) {
			return List.of();
		}

		return quotes.findByBookingIdInOrderByCreatedAtDesc(bookingIds)
			.stream()
			.filter(q -> q.getStatus() == QuoteStatus.SUBMITTED)
			.map(this::toResponse)
			.sorted((a, b) -> {
				BigDecimal totalA = a.items().stream()
					.map(QuoteItem::subtotal)
					.reduce(BigDecimal.ZERO, BigDecimal::add);
				BigDecimal totalB = b.items().stream()
					.map(QuoteItem::subtotal)
					.reduce(BigDecimal.ZERO, BigDecimal::add);
				return totalA.compareTo(totalB);
			})
			.toList();
	}

	/**
	 * 将 trade / category 字符串映射为 catalog category 集合。
	 * 水电动 → PLUMBING + ELECTRICAL；木工 → CARPENTRY 等。
	 * 若传入的是标准 category（如 PLUMBING），直接返回单元素集合。
	 */
	static Set<String> resolveCategories(String input) {
		if (input == null) {
			return Set.of();
		}
		String trimmed = input.trim();
		return switch (trimmed) {
			case "水电动", "水电" -> Set.of("PLUMBING", "ELECTRICAL");
			case "木工" -> Set.of("CARPENTRY");
			case "油漆" -> Set.of("PAINTING");
			case "泥瓦", "泥工" -> Set.of("MASONRY");
			case "拆除" -> Set.of("DEMOLITION");
			case "PLUMBING", "ELECTRICAL", "CARPENTRY",
				 "PAINTING", "MASONRY", "DEMOLITION" -> Set.of(trimmed);
			default -> Set.of(trimmed.toUpperCase());
		};
	}

	private QuoteResponse toResponse(Quote quote) {
		return new QuoteResponse(quote.getId(), quote.getBookingId(),
			quote.getWorkerUserId(), quote.getItems(), quote.getStatus(),
			quote.getRejectReason(),
			quote.getCreatedAt(), quote.getUpdatedAt());
	}
}
