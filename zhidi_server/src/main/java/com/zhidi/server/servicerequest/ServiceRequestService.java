package com.zhidi.server.servicerequest;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingCancellationActor;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingResponse;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.booking.VisitProposal;
import com.zhidi.server.booking.VisitProposalRepository;
import com.zhidi.server.booking.VisitProposalStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ServiceRequestService {
	private final ServiceRequestRepository requests;
	private final BookingRepository bookings;
	private final VisitProposalRepository visitProposals;
	private final WorkerProfileRepository workerProfiles;
	private final OwnerProfileRepository ownerProfiles;
	private final UserRepository users;

	public ServiceRequestService(ServiceRequestRepository requests,
			BookingRepository bookings, VisitProposalRepository visitProposals,
			WorkerProfileRepository workerProfiles, OwnerProfileRepository ownerProfiles,
			UserRepository users) {
		this.requests = requests;
		this.bookings = bookings;
		this.visitProposals = visitProposals;
		this.workerProfiles = workerProfiles;
		this.ownerProfiles = ownerProfiles;
		this.users = users;
	}

	@Transactional
	public ServiceRequestResponse createRequest(UUID ownerUserId,
			ServiceRequestCreateRequest req) {
		ServiceRequest request = ServiceRequest.create(ownerUserId,
			req.trade(), req.serviceCity(),
			req.serviceAddress(), req.areaSqm(), req.bedroomCount(),
			req.livingRoomCount(), req.kitchenCount(), req.bathroomCount(),
			req.remark());
		return toResponse(requests.saveAndFlush(request));
	}

	@Transactional
	public ServiceRequestResponse addCandidate(UUID ownerUserId, UUID requestId,
			CandidateCreateRequest req) {
		lockOwnerAccount(ownerUserId);
		ServiceRequest request = findMutableRequest(ownerUserId, requestId);
		WorkerProfile worker = findEligibleWorker(request, req.workerUserId());
		ensureWorkerNotAlreadyInvited(requestId, req.workerUserId());

		long active = bookings.countActiveCandidates(requestId,
			BookingStatus.CANDIDATE_TERMINAL_STATUSES);
		if (active >= 3) {
			throw new BusinessException(HttpStatus.CONFLICT,
					"CANDIDATE_LIMIT_REACHED", "同一装修需求最多选择 3 位候选师傅");
		}

		bookings.saveAndFlush(createCandidate(request, ownerUserId, worker));

		syncStatus(request);
		return toResponse(request);
	}

	private void lockOwnerAccount(UUID ownerUserId) {
		users.findByIdForUpdate(ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED,
				"AUTHENTICATION_REQUIRED", "owner account is not available"));
	}

	@Transactional
	public ServiceRequestResponse removeCandidate(UUID ownerUserId, UUID requestId,
			UUID bookingId) {
		ServiceRequest request = findMutableRequest(ownerUserId, requestId);
		Booking candidate = findCandidateForUpdate(requestId, bookingId);
		if (!candidate.canBeRemovedAsCandidate()) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"CANDIDATE_CANNOT_REMOVE", "师傅已到场或订单已进入后续流程，不能移除");
		}

		candidate.cancel(BookingCancellationActor.OWNER, "业主移除候选师傅",
			Instant.now());
		bookings.saveAndFlush(candidate);
		syncStatus(request);
		return toResponse(request);
	}

	@Transactional
	public ServiceRequestResponse replaceCandidate(UUID ownerUserId, UUID requestId,
			UUID bookingId, CandidateCreateRequest req) {
		lockOwnerAccount(ownerUserId);
		ServiceRequest request = findMutableRequest(ownerUserId, requestId);
		Booking oldCandidate = findCandidateForUpdate(requestId, bookingId);
		if (!oldCandidate.canBeRemovedAsCandidate()) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"CANDIDATE_CANNOT_REPLACE", "师傅已到场或订单已进入后续流程，不能更换");
		}

		WorkerProfile replacement = findEligibleWorker(request, req.workerUserId());
		ensureWorkerNotAlreadyInvited(requestId, req.workerUserId());

		oldCandidate.cancel(BookingCancellationActor.OWNER, "业主更换候选师傅",
			Instant.now());
		bookings.saveAndFlush(oldCandidate);
		bookings.saveAndFlush(createCandidate(request, ownerUserId, replacement));
		syncStatus(request);
		return toResponse(request);
	}

	@Transactional
	public ServiceRequestResponse reopenRequest(UUID ownerUserId, UUID requestId) {
		ServiceRequest oldRequest = requests.findOwnedForUpdate(requestId, ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"SERVICE_REQUEST_NOT_FOUND", "装修需求不存在"));
		if (oldRequest.getStatus() != ServiceRequestStatus.CANCELLED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"SERVICE_REQUEST_CANNOT_REOPEN", "只有已取消的装修需求可以重新寻找师傅");
		}
		if (oldRequest.getReopenedRequestId() != null) {
			ServiceRequest successor = requests
				.findByIdAndOwnerUserId(oldRequest.getReopenedRequestId(), ownerUserId)
				.orElseThrow(() -> new IllegalStateException(
					"reopen successor is not available"));
			return toResponse(successor);
		}
		ServiceRequest cloned = ServiceRequest.recreate(ownerUserId,
			oldRequest.getTrade(), oldRequest.getServiceCity(),
			oldRequest.getServiceAddress(), oldRequest.getAreaSqm(),
			oldRequest.getBedroomCount(), oldRequest.getLivingRoomCount(),
			oldRequest.getKitchenCount(), oldRequest.getBathroomCount(),
			oldRequest.getRemark());
		ServiceRequest successor = requests.saveAndFlush(cloned);
		oldRequest.markReopenedAs(successor.getId());
		requests.saveAndFlush(oldRequest);
		return toResponse(successor);
	}

	@Transactional(readOnly = true)
	public List<ServiceRequestResponse> listOwnerRequests(UUID ownerUserId) {
		List<ServiceRequest> source =
			requests.findByOwnerUserIdOrderByCreatedAtDesc(ownerUserId);
		if (source.isEmpty()) {
			return List.of();
		}
		List<Booking> allCandidates = bookings
			.findByServiceRequestIdInOrderByCreatedAtAsc(
				source.stream().map(ServiceRequest::getId).toList());
		Map<UUID, List<Booking>> candidatesByRequestId = new LinkedHashMap<>();
		for (Booking candidate : allCandidates) {
			candidatesByRequestId.computeIfAbsent(candidate.getServiceRequestId(),
				ignored -> new java.util.ArrayList<>()).add(candidate);
		}
		Map<UUID, Instant> proposedTimeByBookingId =
			loadVisibleProposedTimes(allCandidates);
		return source.stream()
			.map(request -> toResponse(request,
				candidatesByRequestId.getOrDefault(request.getId(), List.of()),
				proposedTimeByBookingId))
			.toList();
	}

	@Transactional
	public ServiceRequestResponse cancelRequest(UUID ownerUserId, UUID requestId) {
		ServiceRequest request = requests.findOwnedForUpdate(requestId, ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"SERVICE_REQUEST_NOT_FOUND", "装修需求不存在"));

		if (request.getStatus() == ServiceRequestStatus.CANCELLED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"SERVICE_REQUEST_ALREADY_CANCELLED", "该需求已取消");
		}

		Instant now = Instant.now();
		List<Booking> candidates = bookings
			.findByServiceRequestIdOrderByCreatedAtAsc(requestId);
		for (Booking b : candidates) {
			if (b.canCancelBeforeOnSite()) {
				b.cancel(BookingCancellationActor.OWNER, "需求已取消", now);
			}
		}

		request.cancel();
		return toResponse(request);
	}

	private void syncStatus(ServiceRequest request) {
		long active = bookings.countActiveCandidates(request.getId(),
			BookingStatus.CANDIDATE_TERMINAL_STATUSES);
		request.syncActiveCandidateCount(active);
	}

	private ServiceRequest findMutableRequest(UUID ownerUserId, UUID requestId) {
		ServiceRequest request = requests.findOwnedForUpdate(requestId, ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"SERVICE_REQUEST_NOT_FOUND", "装修需求不存在"));
		if (request.getStatus() != ServiceRequestStatus.OPEN
				&& request.getStatus() != ServiceRequestStatus.COMPARING) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"SERVICE_REQUEST_NOT_OPEN", "该装修需求已进入后续流程，不能修改候选师傅");
		}
		return request;
	}

	private Booking findCandidateForUpdate(UUID requestId, UUID bookingId) {
		return bookings.findCandidateForUpdate(bookingId, requestId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"CANDIDATE_NOT_FOUND", "候选师傅不存在"));
	}

	private WorkerProfile findEligibleWorker(ServiceRequest request,
			UUID workerUserId) {
		WorkerProfile worker = workerProfiles
			.findByUserIdAndNameIsNotNullAndServiceCityIsNotNullAndPrimaryTradeIsNotNullAndExperienceYearsIsNotNullAndDailyRateIsNotNullAndBioIsNotNull(
				workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WORKER_NOT_FOUND", "工匠不可用"));
		if (!worker.getPrimaryTrade().equals(request.getTrade())) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WORKER_TRADE_MISMATCH", "工匠工种与装修需求不匹配");
		}
		return worker;
	}

	private void ensureWorkerNotAlreadyInvited(UUID requestId, UUID workerUserId) {
		if (bookings.existsByServiceRequestIdAndWorkerUserId(requestId, workerUserId)) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"CANDIDATE_ALREADY_EXISTS", "该工匠已经是候选");
		}
	}

	private Booking createCandidate(ServiceRequest request, UUID ownerUserId,
			WorkerProfile worker) {
		String ownerName = ownerProfiles.findByUserId(ownerUserId)
			.map(p -> p.getName())
			.orElse("业主");
		String ownerPhone = users.findById(ownerUserId)
			.map(User::getPhone)
			.orElse("");
		return Booking.createCandidate(request, ownerUserId,
			ownerName, ownerPhone, worker.getUserId(), worker.getName());
	}

	private ServiceRequestResponse toResponse(ServiceRequest request) {
		List<Booking> candidates = bookings
			.findByServiceRequestIdOrderByCreatedAtAsc(request.getId());
		return toResponse(request, candidates, loadVisibleProposedTimes(candidates));
	}

	private ServiceRequestResponse toResponse(ServiceRequest request,
			List<Booking> candidates,
			Map<UUID, Instant> proposedTimeByBookingId) {
		long activeCandidateCount = candidates.stream()
			.filter(candidate -> !BookingStatus.CANDIDATE_TERMINAL_STATUSES
				.contains(candidate.getStatus()))
			.count();
		long availableCandidateSlots = Math.max(0, 3 - activeCandidateCount);
		boolean requestCanChangeCandidates =
			(request.getStatus() == ServiceRequestStatus.OPEN
				|| request.getStatus() == ServiceRequestStatus.COMPARING);
		List<BookingResponse> candidateResponses = candidates.stream()
			.map(candidate -> bookingToResponse(candidate, request,
				requestCanChangeCandidates,
				proposedTimeByBookingId.get(candidate.getId()))).toList();

		return new ServiceRequestResponse(request.getId(),
			request.getOwnerUserId(),
			request.getTrade(),
			request.getServiceCity(),
			request.getServiceAddress(),
			request.getRemark(),
			request.getAreaSqm(),
			request.getBedroomCount(),
			request.getLivingRoomCount(),
			request.getKitchenCount(),
			request.getBathroomCount(),
			request.getStatus(),
			candidateResponses,
			request.getCreatedAt(),
			request.getUpdatedAt(),
			activeCandidateCount,
			availableCandidateSlots,
			requestCanChangeCandidates && availableCandidateSlots > 0);
	}

	private BookingResponse bookingToResponse(Booking booking,
			ServiceRequest request,
			boolean requestCanChangeCandidates,
			Instant proposedTime) {
		boolean canChange = requestCanChangeCandidates
			&& booking.canBeRemovedAsCandidate();
		return new BookingResponse(booking.getId(), booking.getServiceRequestId(),
			booking.getOwnerUserId(), booking.getOwnerName(), booking.getOwnerPhone(),
			booking.getWorkerUserId(), booking.getWorkerName(), booking.getTrade(),
			booking.getServiceCity(), booking.getServiceAddress(), booking.getRemark(),
			request.getAreaSqm(), request.getBedroomCount(),
			request.getLivingRoomCount(), request.getKitchenCount(),
			request.getBathroomCount(),
			booking.getStatus(),
			booking.getCancelledBy(), booking.getCancelReason(), booking.getCancelledAt(),
			booking.isArrivalConfirmedByOwner(), booking.isArrivalConfirmedByWorker(),
			booking.getOnSiteAt(), proposedTime,
			booking.getScheduledVisitAt(), booking.getOnSiteAt(),
			booking.getCreatedAt(), booking.getUpdatedAt(), canChange, canChange);
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
}
