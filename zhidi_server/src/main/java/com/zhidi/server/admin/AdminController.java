package com.zhidi.server.admin;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import com.zhidi.server.common.error.BusinessException;
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
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.persistence.criteria.Predicate;

@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

	private final UserRepository userRepository;
	private final BookingRepository bookingRepository;

	public AdminController(UserRepository userRepository,
			BookingRepository bookingRepository) {
		this.userRepository = userRepository;
		this.bookingRepository = bookingRepository;
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

		Specification<Booking> spec = (root, query, cb) -> {
			var predicates = new java.util.ArrayList<Predicate>();
			if (StringUtils.hasText(status)) {
				try {
					BookingStatus bs = BookingStatus.valueOf(status.toUpperCase());
					predicates.add(cb.equal(root.get("status"), bs));
				} catch (IllegalArgumentException ignored) {
				}
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
			PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt")));
		return ResponseEntity.ok(ApiResponse.ok(result, traceId()));
	}

	@GetMapping("/users")
	ResponseEntity<ApiResponse<Page<User>>> listUsers(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size,
			@RequestParam(required = false) String phone,
			@RequestParam(required = false) String role) {

		Specification<User> spec = (root, query, cb) -> {
			var predicates = new java.util.ArrayList<Predicate>();
			if (StringUtils.hasText(phone)) {
				predicates.add(cb.like(root.get("phone"), "%" + phone.trim() + "%"));
			}
			if (StringUtils.hasText(role)) {
				query.distinct(true);
				var join = root.join("roles");
				predicates.add(cb.equal(join.get("role"),
					com.zhidi.server.account.UserRole.valueOf(role.toUpperCase())));
			}
			return cb.and(predicates.toArray(new Predicate[0]));
		};

		Page<User> result = userRepository.findAll(spec,
			PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt")));
		return ResponseEntity.ok(ApiResponse.ok(result, traceId()));
	}

	@PutMapping("/bookings/{bookingId}/status")
	ResponseEntity<ApiResponse<Booking>> updateBookingStatus(
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
		return ResponseEntity.ok(ApiResponse.ok(booking, traceId()));
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
