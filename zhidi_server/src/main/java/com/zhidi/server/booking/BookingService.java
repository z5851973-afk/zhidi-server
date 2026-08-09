package com.zhidi.server.booking;

import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.payment.WorkerWarrantyAccountService;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.servicerequest.ServiceRequestStatus;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.simp.SimpMessagingTemplate;
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
	private final VisitProposalRepository visitProposals;
	private final SimpMessagingTemplate messagingTemplate;
	private final WorkerWarrantyAccountService workerWarrantyAccounts;

	public BookingService(BookingRepository bookings,
			ServiceRequestRepository serviceRequests,
			WorkerProfileRepository workerProfiles, UserRepository users,
			OwnerProfileRepository ownerProfiles,
			VisitProposalRepository visitProposals,
			SimpMessagingTemplate messagingTemplate,
			WorkerWarrantyAccountService workerWarrantyAccounts) {
		this.bookings = bookings;
		this.serviceRequests = serviceRequests;
		this.workerProfiles = workerProfiles;
		this.users = users;
		this.ownerProfiles = ownerProfiles;
		this.visitProposals = visitProposals;
		this.messagingTemplate = messagingTemplate;
		this.workerWarrantyAccounts = workerWarrantyAccounts;
	}

	@Transactional
	public BookingResponse create(UUID ownerUserId, BookingRequest request) {
		User owner = users.findByIdForUpdate(ownerUserId)
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
		String serviceAddress = blankToNull(request.serviceAddress());
		String remark = blankToNull(request.remark());

		List<ServiceRequest> exactRequests = serviceRequests
			.findByOwnerUserIdAndTradeAndServiceCityAndStatusInOrderByCreatedAtDesc(
				ownerUserId, trade, serviceCity,
				List.of(ServiceRequestStatus.OPEN, ServiceRequestStatus.COMPARING))
			.stream()
			.filter(existing -> matchesDirectProject(existing, serviceAddress,
				request))
			.toList();
		Booking activeRetry = exactRequests.isEmpty() ? null : bookings
			.findActiveByServiceRequestIdsAndWorkerUserId(
				exactRequests.stream().map(ServiceRequest::getId).toList(),
				worker.getUserId(), BookingStatus.CANDIDATE_TERMINAL_STATUSES)
			.stream().findFirst().orElse(null);
		if (activeRetry != null) {
			ServiceRequest lockedRetryRequest = lockMatchingDirectRequest(
				activeRetry.getServiceRequestId(), ownerUserId, serviceAddress, request);
			if (lockedRetryRequest != null) {
				Booking reloadedRetry = bookings
					.findByServiceRequestIdAndWorkerUserId(lockedRetryRequest.getId(),
						worker.getUserId())
					.orElse(null);
				if (isActiveCandidate(reloadedRetry)) {
					return toResponse(reloadedRetry);
				}
			}
		}

		ServiceRequest serviceRequest = exactRequests.isEmpty() ? null
			: lockMatchingDirectRequest(exactRequests.getFirst().getId(),
				ownerUserId, serviceAddress, request);
		if (serviceRequest != null) {
			Booking existingBooking = bookings
				.findByServiceRequestIdAndWorkerUserId(serviceRequest.getId(),
					worker.getUserId())
				.orElse(null);
			if (isActiveCandidate(existingBooking)) {
				return toResponse(existingBooking);
			}
			long activeCandidateCount = bookings.countActiveCandidates(
				serviceRequest.getId(), BookingStatus.CANDIDATE_TERMINAL_STATUSES);
			if (existingBooking != null || activeCandidateCount >= 3) {
				serviceRequest = null;
			}
		}
		if (serviceRequest == null) {
			serviceRequest = ServiceRequest.create(ownerUserId, trade, serviceCity,
				serviceAddress, request.areaSqm(), request.bedroomCount(),
				request.livingRoomCount(), request.kitchenCount(),
				request.bathroomCount(), remark);
			serviceRequest = serviceRequests.saveAndFlush(serviceRequest);
		}

		Booking booking = Booking.createCandidate(serviceRequest, ownerUserId,
			ownerName, owner.getPhone(), worker.getUserId(), worker.getName());
		Booking saved = bookings.saveAndFlush(booking);
		syncServiceRequestStatus(serviceRequest.getId());
		return toResponse(saved);
	}

	private ServiceRequest lockMatchingDirectRequest(UUID requestId,
			UUID ownerUserId, String serviceAddress, BookingRequest request) {
		return serviceRequests.findOwnedForUpdate(requestId, ownerUserId)
			.filter(existing -> isMutableCandidateRequest(existing)
				&& matchesDirectProject(existing, serviceAddress, request))
			.orElse(null);
	}

	private boolean isMutableCandidateRequest(ServiceRequest request) {
		return request.getStatus() == ServiceRequestStatus.OPEN
			|| request.getStatus() == ServiceRequestStatus.COMPARING;
	}

	private boolean isActiveCandidate(Booking booking) {
		return booking != null && !BookingStatus.CANDIDATE_TERMINAL_STATUSES
			.contains(booking.getStatus());
	}

	@Transactional(readOnly = true)
	public List<BookingResponse> listForOwner(UUID ownerUserId) {
		return toResponses(bookings.findByOwnerUserIdOrderByCreatedAtDesc(ownerUserId));
	}

	@Transactional(readOnly = true)
	public List<BookingResponse> listForWorker(UUID workerUserId) {
		return toResponses(bookings.findByWorkerUserIdOrderByCreatedAtDesc(workerUserId));
	}

	@Transactional
	public BookingResponse accept(UUID workerUserId, UUID bookingId) {
		if (!workerWarrantyAccounts.canAcceptNewJobsForUpdate(workerUserId)) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WORKER_WARRANTY_TOP_UP_REQUIRED",
				"履约质保金待补足，完成核验后可继续接单");
		}
		Booking booking = findWorkerBookingForUpdate(workerUserId, bookingId);
		booking.accept();
		syncServiceRequestStatus(booking.getServiceRequestId());
		pushStatusChange(booking);
		return toResponse(booking);
	}

	private boolean matchesDirectProject(ServiceRequest existing,
			String serviceAddress, BookingRequest request) {
		return Objects.equals(existing.getServiceAddress(), serviceAddress)
			&& sameDecimal(existing.getAreaSqm(), request.areaSqm())
			&& Objects.equals(existing.getBedroomCount(), request.bedroomCount())
			&& Objects.equals(existing.getLivingRoomCount(), request.livingRoomCount())
			&& Objects.equals(existing.getKitchenCount(), request.kitchenCount())
			&& Objects.equals(existing.getBathroomCount(), request.bathroomCount());
	}

	private boolean sameDecimal(BigDecimal left, BigDecimal right) {
		return left != null && right != null && left.compareTo(right) == 0;
	}

	@Transactional
	public BookingResponse reject(UUID workerUserId, UUID bookingId) {
		Booking booking = findWorkerBooking(workerUserId, bookingId);
		booking.reject();
		syncServiceRequestStatus(booking.getServiceRequestId());
		pushStatusChange(booking);
		return toResponse(booking);
	}

	@Transactional
	public BookingResponse ownerCancel(UUID ownerUserId, UUID bookingId,
			String reason) {
		Booking booking = bookings.findByIdAndOwnerUserId(bookingId, ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));
		ensureCancellable(booking);
		booking.cancel(BookingCancellationActor.OWNER, reason, Instant.now());
		syncServiceRequestStatus(booking.getServiceRequestId());
		pushStatusChange(booking);
		return toResponse(booking);
	}

	@Transactional
	public BookingResponse workerCancel(UUID workerUserId, UUID bookingId,
			String reason) {
		Booking booking = findWorkerBooking(workerUserId, bookingId);
		ensureCancellable(booking);
		booking.cancel(BookingCancellationActor.WORKER, reason, Instant.now());
		syncServiceRequestStatus(booking.getServiceRequestId());
		pushStatusChange(booking);
		return toResponse(booking);
	}

	private void ensureCancellable(Booking booking) {
		if (booking.canCancelBeforeOnSite()) {
			return;
		}
		throw new BusinessException(HttpStatus.CONFLICT,
			"BOOKING_CANNOT_CANCEL", "师傅已上门或订单已进入后续流程，不能直接取消，请联系客服处理");
	}

	private Booking findWorkerBooking(UUID workerUserId, UUID bookingId) {
		return bookings.findByIdAndWorkerUserId(bookingId, workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));
	}

	private Booking findWorkerBookingForUpdate(UUID workerUserId, UUID bookingId) {
		Booking booking = bookings.findByIdForUpdate(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));
		if (!Objects.equals(booking.getWorkerUserId(), workerUserId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available");
		}
		return booking;
	}

	private void syncServiceRequestStatus(UUID requestId) {
		serviceRequests.findById(requestId).ifPresent(request ->
			request.syncActiveCandidateCount(
				bookings.countActiveCandidates(requestId,
					BookingStatus.CANDIDATE_TERMINAL_STATUSES)));
	}

	private BookingResponse toResponse(Booking booking) {
		ServiceRequest request = serviceRequests.findById(booking.getServiceRequestId())
			.orElse(null);
		return toResponse(booking, request);
	}

	private List<BookingResponse> toResponses(List<Booking> source) {
		if (source.isEmpty()) {
			return List.of();
		}
		Map<UUID, ServiceRequest> requestById = new LinkedHashMap<>();
		serviceRequests.findAllById(source.stream()
			.map(Booking::getServiceRequestId).distinct().toList())
			.forEach(request -> requestById.put(request.getId(), request));
		Map<UUID, Instant> proposedTimeByBookingId =
			loadVisibleProposedTimes(source);
		return source.stream()
			.map(booking -> toResponse(booking,
				requestById.get(booking.getServiceRequestId()),
				proposedTimeByBookingId.get(booking.getId())))
			.toList();
	}

	private BookingResponse toResponse(Booking booking, ServiceRequest request) {
		return toResponse(booking, request, findVisibleProposedTime(booking));
	}

	private BookingResponse toResponse(Booking booking, ServiceRequest request,
			Instant proposedTime) {

		return new BookingResponse(booking.getId(), booking.getServiceRequestId(),
			booking.getOwnerUserId(), booking.getOwnerName(), booking.getOwnerPhone(),
			booking.getWorkerUserId(), booking.getWorkerName(), booking.getTrade(),
			booking.getServiceCity(), booking.getServiceAddress(), booking.getRemark(),
			request == null ? null : request.getAreaSqm(),
			request == null ? null : request.getBedroomCount(),
			request == null ? null : request.getLivingRoomCount(),
			request == null ? null : request.getKitchenCount(),
			request == null ? null : request.getBathroomCount(),
			booking.getStatus(),
			booking.getCancelledBy(), booking.getCancelReason(), booking.getCancelledAt(),
			booking.isArrivalConfirmedByOwner(), booking.isArrivalConfirmedByWorker(),
			booking.getOnSiteAt(), proposedTime,
			booking.getScheduledVisitAt(), booking.getOnSiteAt(),
			booking.getCreatedAt(), booking.getUpdatedAt(), false, false);
	}

	private Instant findVisibleProposedTime(Booking booking) {
		VisitProposalStatus proposalStatus = visibleProposalStatus(booking);
		if (proposalStatus == null) {
			return null;
		}
		return visitProposals
			.findFirstByBookingIdAndStatusOrderByCreatedAtDesc(
				booking.getId(), proposalStatus)
			.map(VisitProposal::getProposedTime)
			.orElse(null);
	}

	private Map<UUID, Instant> loadVisibleProposedTimes(List<Booking> source) {
		Map<UUID, VisitProposalStatus> desiredStatusByBookingId =
			new LinkedHashMap<>();
		for (Booking booking : source) {
			VisitProposalStatus status = visibleProposalStatus(booking);
			if (status != null) {
				desiredStatusByBookingId.put(booking.getId(), status);
			}
		}
		if (desiredStatusByBookingId.isEmpty()) {
			return Map.of();
		}
		Map<UUID, Instant> proposedTimeByBookingId = new LinkedHashMap<>();
		visitProposals.findVisibleByBookingIds(
			desiredStatusByBookingId.keySet(),
			Set.copyOf(desiredStatusByBookingId.values()))
			.forEach(proposal -> {
				if (proposal.getStatus() == desiredStatusByBookingId
						.get(proposal.getBookingId())) {
					proposedTimeByBookingId.putIfAbsent(proposal.getBookingId(),
						proposal.getProposedTime());
				}
			});
		return proposedTimeByBookingId;
	}

	private VisitProposalStatus visibleProposalStatus(Booking booking) {
		return switch (booking.getStatus()) {
			case VISIT_PROPOSED -> VisitProposalStatus.PROPOSED;
			case VISIT_SCHEDULED, ARRIVAL_PENDING, ON_SITE, QUOTE_PENDING,
				 READY_TO_START, HIRED, COMPLETED ->
				VisitProposalStatus.ACCEPTED;
			default -> null;
		};
	}

	@Transactional
	public BookingResponse proposeVisit(UUID workerUserId, UUID bookingId,
			Instant proposedTime) {
		Booking booking = findWorkerBooking(workerUserId, bookingId);
		booking.proposeVisit();

		VisitProposal proposal = new VisitProposal(booking.getId(),
			VisitProposalActor.WORKER, proposedTime);
		visitProposals.save(proposal);
		bookings.save(booking);

		pushStatusChange(booking);
		return toResponse(booking);
	}

	@Transactional
	public BookingResponse acceptVisit(UUID ownerUserId, UUID bookingId) {
		Booking booking = bookings.findByIdAndOwnerUserId(bookingId, ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));
		VisitProposal proposal = visitProposals
			.findFirstByBookingIdAndStatusOrderByCreatedAtDesc(
				booking.getId(), VisitProposalStatus.PROPOSED)
			.orElseThrow(() -> new BusinessException(HttpStatus.CONFLICT,
				"NO_PROPOSAL", "no pending visit proposal"));
		booking.scheduleVisit(proposal.getProposedTime());
		proposal.accept();
		visitProposals.save(proposal);
		bookings.save(booking);

		pushStatusChange(booking);
		return toResponse(booking);
	}

	@Transactional
	public BookingResponse rejectVisit(UUID ownerUserId, UUID bookingId,
			String reason) {
		Booking booking = bookings.findByIdAndOwnerUserId(bookingId, ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));
		VisitProposal proposal = visitProposals
			.findFirstByBookingIdAndStatusOrderByCreatedAtDesc(
				booking.getId(), VisitProposalStatus.PROPOSED)
			.orElseThrow(() -> new BusinessException(HttpStatus.CONFLICT,
				"NO_PROPOSAL", "no pending visit proposal"));
		booking.revertToAccepted();
		proposal.reject(reason);
		visitProposals.save(proposal);
		bookings.save(booking);

		pushStatusChange(booking);
		return toResponse(booking);
	}

	@Transactional
	public BookingResponse arrive(UUID userId, UUID bookingId, boolean isWorker) {
		Booking booking = findParticipantBookingForUpdate(userId, bookingId, isWorker);

		if (booking.getStatus() == BookingStatus.ON_SITE) {
			return toResponse(booking);
		}

		if (isWorker) {
			booking.confirmArrivalByWorker();
		} else {
			booking.confirmArrivalByOwner();
		}
		bookings.save(booking);

		pushStatusChange(booking);
		return toResponse(booking);
	}

	@Transactional
	public BookingResponse confirmArrival(UUID userId, UUID bookingId,
			boolean isWorker) {
		Booking booking = findParticipantBookingForUpdate(userId, bookingId, isWorker);

		if (booking.getStatus() == BookingStatus.ON_SITE) {
			return toResponse(booking);
		}

		if (booking.getStatus() != BookingStatus.ARRIVAL_PENDING) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS",
				"只有双方已标记到达(ARRIVAL_PENDING)才能确认到场");
		}

		if (isWorker && !booking.isArrivalConfirmedByOwner()) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"OWNER_NOT_ARRIVED", "业主尚未标记到达");
		}
		if (!isWorker && !booking.isArrivalConfirmedByWorker()) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WORKER_NOT_ARRIVED", "工人尚未标记到达");
		}

		if (isWorker) {
			booking.confirmArrivalByWorker();
		} else {
			booking.confirmArrivalByOwner();
		}
		bookings.save(booking);

		pushStatusChange(booking);
		return toResponse(booking);
	}

	private Booking findParticipantBookingForUpdate(UUID userId, UUID bookingId,
			boolean isWorker) {
		Booking booking = bookings.findByIdForUpdate(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));
		UUID participantId = isWorker
			? booking.getWorkerUserId()
			: booking.getOwnerUserId();
		if (!participantId.equals(userId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available");
		}
		return booking;
	}

	private void pushStatusChange(Booking booking) {
		messagingTemplate.convertAndSend(
			"/topic/booking/" + booking.getId(),
			Map.of("bookingId", booking.getId().toString(),
				"status", booking.getStatus().name(),
				"timestamp", Instant.now().toString()));
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
