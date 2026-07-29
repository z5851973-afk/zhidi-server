package com.zhidi.server.admin;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.audit.OperationLog;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.transaction.annotation.Transactional;

import jakarta.persistence.criteria.Predicate;

@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

	private final UserRepository userRepository;
	private final BookingRepository bookingRepository;
	private final OperationLogRepository operationLogRepository;

	public AdminController(UserRepository userRepository,
			BookingRepository bookingRepository,
			OperationLogRepository operationLogRepository) {
		this.userRepository = userRepository;
		this.bookingRepository = bookingRepository;
		this.operationLogRepository = operationLogRepository;
	}

	@GetMapping("/dashboard")
	ResponseEntity<ApiResponse<DashboardResponse>> dashboard() {
		long todayStart = LocalDate.now()
			.atStartOfDay(ZoneId.systemDefault()).toEpochSecond();

		long totalUsers = userRepository.count();
		long newUsersToday = userRepository.countByCreatedAtAfter(
			Instant.ofEpochSecond(todayStart));

		List<Booking> allBookings = bookingRepository.findAll();
		long activeBookings = allBookings.stream()
			.filter(b -> !isTerminal(b.getStatus()))
			.count();

		Map<String, Long> statusDistribution = new java.util.HashMap<>();
		for (Booking b : allBookings) {
			statusDistribution.merge(b.getStatus().name(), 1L, Long::sum);
		}

		DashboardResponse dashboard = new DashboardResponse(
			totalUsers, newUsersToday, activeBookings, statusDistribution);
		return ResponseEntity.ok(ApiResponse.ok(dashboard, traceId()));
	}

	@GetMapping("/bookings")
	ResponseEntity<ApiResponse<Page<Booking>>> listBookings(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size,
			@RequestParam(required = false) String status,
			@RequestParam(required = false) String trade,
			@RequestParam(required = false)
				@DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
			@RequestParam(required = false)
				@DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
		BookingStatus statusFilter = parseBookingStatusFilter(status);

		Specification<Booking> spec = (root, query, cb) -> {
			var predicates = new java.util.ArrayList<Predicate>();
			if (statusFilter != null) {
				predicates.add(cb.equal(root.get("status"), statusFilter));
			}
			if (StringUtils.hasText(trade)) {
				predicates.add(cb.equal(root.get("trade"), trade));
			}
			if (startDate != null) {
				predicates.add(cb.greaterThanOrEqualTo(root.get("createdAt"),
					startDate.atStartOfDay(ZoneId.systemDefault()).toInstant()));
			}
			if (endDate != null) {
				predicates.add(cb.lessThanOrEqualTo(root.get("createdAt"),
					endDate.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()));
			}
			return cb.and(predicates.toArray(new Predicate[0]));
		};

		Page<Booking> result = bookingRepository.findAll(spec,
			pageRequest(page, size));
		return ResponseEntity.ok(ApiResponse.ok(result, traceId()));
	}

	@GetMapping("/users")
	ResponseEntity<ApiResponse<Page<User>>> listUsers(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size,
			@RequestParam(required = false) String phone,
			@RequestParam(required = false) String role) {
		UserRole roleFilter = parseUserRoleFilter(role);

		Specification<User> spec = (root, query, cb) -> {
			var predicates = new java.util.ArrayList<Predicate>();
			if (StringUtils.hasText(phone)) {
				predicates.add(cb.like(root.get("phone"), "%" + phone.trim() + "%"));
			}
			if (roleFilter != null) {
				query.distinct(true);
				var join = root.join("roles");
				predicates.add(cb.equal(join.get("role"), roleFilter));
			}
			return cb.and(predicates.toArray(new Predicate[0]));
		};

		Page<User> result = userRepository.findAll(spec,
			pageRequest(page, size));
		return ResponseEntity.ok(ApiResponse.ok(result, traceId()));
	}

	@PutMapping("/bookings/{bookingId}/status")
	@Transactional
	ResponseEntity<ApiResponse<Booking>> updateBookingStatus(
			@AuthenticationPrincipal CurrentUserPrincipal principal,
			@PathVariable UUID bookingId,
			@RequestParam String status) {
		Booking booking = bookingRepository.findById(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking not found"));

		BookingStatus newStatus;
		try {
			newStatus = BookingStatus.valueOf(status.toUpperCase());
		} catch (IllegalArgumentException e) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_STATUS", "invalid booking status: " + status);
		}

		switch (newStatus) {
			case ACCEPTED -> booking.accept();
			case CANCELLED -> booking.cancel(
				com.zhidi.server.booking.BookingCancellationActor.OWNER,
				"管理员手动干预", Instant.now());
			case HIRED -> booking.hire();
			default -> throw new BusinessException(HttpStatus.BAD_REQUEST,
				"UNSUPPORTED_STATUS_CHANGE",
				"admin cannot directly set status to " + newStatus);
		}

		bookingRepository.save(booking);
		operationLogRepository.save(OperationLog.success(
			principal.userId(),
			"ADMIN_BOOKING_STATUS_CHANGE",
			"BOOKING",
			bookingId.toString(),
			traceId(),
			"{\"status\":\"" + newStatus.name() + "\"}"));
		return ResponseEntity.ok(ApiResponse.ok(booking, traceId()));
	}

	private PageRequest pageRequest(int page, int size) {
		if (page < 0 || size < 1 || size > 100) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_PAGE", "page must be >= 0 and size must be between 1 and 100");
		}
		return PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
	}

	private BookingStatus parseBookingStatusFilter(String status) {
		if (!StringUtils.hasText(status)) {
			return null;
		}
		try {
			return BookingStatus.valueOf(status.trim().toUpperCase());
		} catch (IllegalArgumentException e) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_STATUS_FILTER", "invalid booking status: " + status);
		}
	}

	private UserRole parseUserRoleFilter(String role) {
		if (!StringUtils.hasText(role)) {
			return null;
		}
		try {
			return UserRole.valueOf(role.trim().toUpperCase());
		} catch (IllegalArgumentException e) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_ROLE_FILTER", "invalid user role: " + role);
		}
	}

	private static boolean isTerminal(BookingStatus status) {
		return switch (status) {
			case CANCELLED, NOT_SELECTED, REJECTED -> true;
			default -> false;
		};
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
