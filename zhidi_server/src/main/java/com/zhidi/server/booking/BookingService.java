package com.zhidi.server.booking;

import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.servicerequest.ServiceRequestStatus;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class BookingService {

	private final BookingRepository bookings;
	private final ServiceRequestRepository serviceRequests;
	private final WorkerProfileRepository workerProfiles;
	private final UserRepository users;
	private final OwnerProfileRepository ownerProfiles;

	public BookingService(BookingRepository bookings,
			ServiceRequestRepository serviceRequests,
			WorkerProfileRepository workerProfiles, UserRepository users,
			OwnerProfileRepository ownerProfiles) {
		this.bookings = bookings;
		this.serviceRequests = serviceRequests;
		this.workerProfiles = workerProfiles;
		this.users = users;
		this.ownerProfiles = ownerProfiles;
	}

	@Transactional
	public BookingResponse create(UUID ownerUserId, BookingRequest request) {
		User owner = users.findById(ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED,
				"AUTHENTICATION_REQUIRED", "owner account is not available"));
		String ownerName = ownerProfiles.findByUserId(ownerUserId)
			.map(profile -> normalize(profile.getName(), "业主"))
			.orElse("业主");
		WorkerProfile worker = workerProfiles
			.findByUserIdAndNameIsNotNullAndServiceCityIsNotNullAndPrimaryTradeIsNotNullAndExperienceYearsIsNotNullAndDailyRateIsNotNullAndBioIsNotNull(
				request.workerUserId())
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WORKER_NOT_FOUND", "worker is not available"));

		String trade = normalize(request.trade(), worker.getPrimaryTrade());
		String serviceCity = normalize(request.serviceCity(), worker.getServiceCity());

		ServiceRequest serviceRequest = serviceRequests
			.findByOwnerUserIdAndTradeAndServiceCityAndStatusOrderByCreatedAtDesc(
				ownerUserId, trade, serviceCity, ServiceRequestStatus.OPEN)
			.stream()
			.findFirst()
			.filter(sr -> !bookings.existsByServiceRequestIdAndWorkerUserId(
				sr.getId(), worker.getUserId()))
			.orElseGet(() -> {
				ServiceRequest sr = ServiceRequest.create(ownerUserId,
					trade, serviceCity,
					blankToNull(request.serviceAddress()),
					blankToNull(request.remark()));
				return serviceRequests.saveAndFlush(sr);
			});

		Booking booking = Booking.createCandidate(serviceRequest, ownerUserId,
			ownerName, owner.getPhone(), worker.getUserId(), worker.getName());
		return toResponse(bookings.saveAndFlush(booking));
	}

	@Transactional(readOnly = true)
	public List<BookingResponse> listForOwner(UUID ownerUserId) {
		return bookings.findByOwnerUserIdOrderByCreatedAtDesc(ownerUserId)
			.stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public List<BookingResponse> listForWorker(UUID workerUserId) {
		return bookings.findByWorkerUserIdOrderByCreatedAtDesc(workerUserId)
			.stream().map(this::toResponse).toList();
	}

	@Transactional
	public BookingResponse accept(UUID workerUserId, UUID bookingId) {
		Booking booking = findWorkerBooking(workerUserId, bookingId);
		booking.accept();

		List<Booking> candidates = bookings
			.findByServiceRequestIdOrderByCreatedAtAsc(booking.getServiceRequestId());
		for (Booking other : candidates) {
			if (!other.getId().equals(bookingId) && other.getStatus() == BookingStatus.PENDING) {
				other.notSelect();
			}
		}

		serviceRequests.findById(booking.getServiceRequestId())
			.ifPresent(ServiceRequest::selectWorker);

		return toResponse(booking);
	}

	@Transactional
	public BookingResponse reject(UUID workerUserId, UUID bookingId) {
		Booking booking = findWorkerBooking(workerUserId, bookingId);
		booking.reject();

		long pendingCount = bookings
			.findByServiceRequestIdOrderByCreatedAtAsc(booking.getServiceRequestId())
			.stream()
			.filter(b -> b.getStatus() == BookingStatus.PENDING)
			.count();
		if (pendingCount == 0) {
			serviceRequests.findById(booking.getServiceRequestId())
				.ifPresent(ServiceRequest::reopen);
		}

		return toResponse(booking);
	}

	@Transactional
	public BookingResponse ownerCancel(UUID ownerUserId, UUID bookingId,
			String reason) {
		Booking booking = bookings.findByIdAndOwnerUserId(bookingId, ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));
		booking.cancel(BookingCancellationActor.OWNER, reason, Instant.now());
		return toResponse(booking);
	}

	@Transactional
	public BookingResponse workerCancel(UUID workerUserId, UUID bookingId,
			String reason) {
		Booking booking = findWorkerBooking(workerUserId, bookingId);
		booking.cancel(BookingCancellationActor.WORKER, reason, Instant.now());
		return toResponse(booking);
	}

	private Booking findWorkerBooking(UUID workerUserId, UUID bookingId) {
		return bookings.findByIdAndWorkerUserId(bookingId, workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));
	}

	private BookingResponse toResponse(Booking booking) {
		return new BookingResponse(booking.getId(), booking.getServiceRequestId(),
			booking.getOwnerUserId(), booking.getOwnerName(), booking.getOwnerPhone(),
			booking.getWorkerUserId(), booking.getWorkerName(), booking.getTrade(),
			booking.getServiceCity(), booking.getServiceAddress(), booking.getRemark(),
			booking.getStatus(),
			booking.getCancelledBy(), booking.getCancelReason(), booking.getCancelledAt(),
			booking.getCreatedAt(), booking.getUpdatedAt());
	}

	private static String normalize(String value, String fallback) {
		String trimmed = blankToNull(value);
		return trimmed == null ? fallback : trimmed;
	}

	private static String blankToNull(String value) {
		if (!StringUtils.hasText(value)) {
			return null;
		}
		return value.trim();
	}
}
