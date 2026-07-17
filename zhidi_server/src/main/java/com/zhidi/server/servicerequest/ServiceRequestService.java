package com.zhidi.server.servicerequest;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingResponse;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.worker.WorkerProfile;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ServiceRequestService {

	private static final Set<BookingStatus> TERMINAL = Set.of(
		BookingStatus.REJECTED,
		BookingStatus.CANCELLED,
		BookingStatus.NOT_SELECTED);

	private final ServiceRequestRepository requests;
	private final BookingRepository bookings;
	private final WorkerProfileRepository workerProfiles;
	private final OwnerProfileRepository ownerProfiles;
	private final UserRepository users;

	public ServiceRequestService(ServiceRequestRepository requests,
			BookingRepository bookings, WorkerProfileRepository workerProfiles,
			OwnerProfileRepository ownerProfiles, UserRepository users) {
		this.requests = requests;
		this.bookings = bookings;
		this.workerProfiles = workerProfiles;
		this.ownerProfiles = ownerProfiles;
		this.users = users;
	}

	@Transactional
	public ServiceRequestResponse createRequest(UUID ownerUserId,
			ServiceRequestCreateRequest req) {
		ServiceRequest request = ServiceRequest.create(ownerUserId,
			req.trade(), req.serviceCity(),
			req.serviceAddress(), req.remark());
		return toResponse(requests.saveAndFlush(request));
	}

	@Transactional
	public ServiceRequestResponse addCandidate(UUID ownerUserId, UUID requestId,
			CandidateCreateRequest req) {
		ServiceRequest request = requests.findOwnedForUpdate(requestId, ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"SERVICE_REQUEST_NOT_FOUND", "装修需求不存在"));

		WorkerProfile worker = workerProfiles
			.findByUserIdAndNameIsNotNullAndServiceCityIsNotNullAndPrimaryTradeIsNotNullAndExperienceYearsIsNotNullAndDailyRateIsNotNullAndBioIsNotNull(
				req.workerUserId())
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WORKER_NOT_FOUND", "工匠不可用"));

		String workerTrade = worker.getPrimaryTrade();
		if (!workerTrade.equals(request.getTrade())) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WORKER_TRADE_MISMATCH", "工匠工种与装修需求不匹配");
		}

		if (bookings.existsByServiceRequestIdAndWorkerUserId(requestId,
			req.workerUserId())) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"CANDIDANT_ALREADY_EXISTS", "该工匠已经是候选");
		}

		long active = bookings.countActiveCandidates(requestId, TERMINAL);
		if (active >= 3) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"CANDIDANT_LIMIT_REACHED", "同一装修需求最多选择 3 位候选师傅");
		}

		String ownerName = ownerProfiles.findByUserId(ownerUserId)
			.map(p -> p.getName())
			.orElse("业主");
		String ownerPhone = users.findById(ownerUserId)
			.map(User::getPhone)
			.orElse("");
		Booking candidate = Booking.createCandidate(request, ownerUserId,
			ownerName, ownerPhone, worker.getUserId(), worker.getName());
		bookings.saveAndFlush(candidate);

		syncStatus(request);
		return toResponse(request);
	}

	@Transactional(readOnly = true)
	public List<ServiceRequestResponse> listOwnerRequests(UUID ownerUserId) {
		return requests.findByOwnerUserIdOrderByCreatedAtDesc(ownerUserId)
			.stream().map(this::toResponse).toList();
	}

	private void syncStatus(ServiceRequest request) {
		long active = bookings.countActiveCandidates(request.getId(), TERMINAL);
		if (active == 0) {
			request.setStatus(ServiceRequestStatus.OPEN);
		} else if (active <= 3) {
			request.setStatus(ServiceRequestStatus.COMPARING);
		}
	}

	private ServiceRequestResponse toResponse(ServiceRequest request) {
		List<Booking> candidates = bookings
			.findByServiceRequestIdOrderByCreatedAtAsc(request.getId());
		List<BookingResponse> candidateResponses = candidates.stream()
			.map(this::bookingToResponse).toList();

		return new ServiceRequestResponse(request.getId(),
			request.getOwnerUserId(),
			request.getTrade(),
			request.getServiceCity(),
			request.getServiceAddress(),
			request.getRemark(),
			request.getStatus(),
			candidateResponses,
			request.getCreatedAt(),
			request.getUpdatedAt());
	}

	private BookingResponse bookingToResponse(Booking booking) {
		return new BookingResponse(booking.getId(), booking.getServiceRequestId(),
			booking.getOwnerUserId(), booking.getOwnerName(), booking.getOwnerPhone(),
			booking.getWorkerUserId(), booking.getWorkerName(), booking.getTrade(),
			booking.getServiceCity(), booking.getServiceAddress(), booking.getRemark(),
			booking.getStatus(),
			booking.getCancelledBy(), booking.getCancelReason(), booking.getCancelledAt(),
			booking.getCreatedAt(), booking.getUpdatedAt());
	}
}
