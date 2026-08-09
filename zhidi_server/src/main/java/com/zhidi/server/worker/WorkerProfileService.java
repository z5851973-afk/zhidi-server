package com.zhidi.server.worker;

import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.workercase.WorkerCaseRepository;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class WorkerProfileService {

	private static final String DEFAULT_CITY = "成都";

	private final WorkerProfileRepository repository;
	private final WorkerCaseRepository workerCases;
	private final BookingRepository bookings;

	public WorkerProfileService(WorkerProfileRepository repository,
			WorkerCaseRepository workerCases, BookingRepository bookings) {
		this.repository = repository;
		this.workerCases = workerCases;
		this.bookings = bookings;
	}

	@Transactional(readOnly = true)
	public WorkerProfileResponse get(UUID userId, String phone) {
		Objects.requireNonNull(userId);
		return repository.findByUserId(userId)
			.map(profile -> toResponse(profile, phone))
			.orElseGet(() -> new WorkerProfileResponse(
				userId, phone, null, DEFAULT_CITY, null, null, null, null, false));
	}

	@Transactional(readOnly = true)
	public List<WorkerDirectoryResponse> listVisible() {
		return repository
			.findByNameIsNotNullAndServiceCityIsNotNullAndPrimaryTradeIsNotNullAndExperienceYearsIsNotNullAndDailyRateIsNotNullAndBioIsNotNullOrderByUpdatedAtDesc()
			.stream()
			.map(this::toDirectoryResponse)
			.toList();
	}

	@Transactional(readOnly = true)
	public WorkerDirectoryResponse getVisible(UUID userId) {
		Objects.requireNonNull(userId);
		return repository
			.findByUserIdAndNameIsNotNullAndServiceCityIsNotNullAndPrimaryTradeIsNotNullAndExperienceYearsIsNotNullAndDailyRateIsNotNullAndBioIsNotNull(userId)
			.map(this::toDirectoryResponse)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WORKER_NOT_FOUND", "worker is not available"));
	}

	@Transactional
	public WorkerProfileResponse update(UUID userId, String phone, WorkerProfileRequest request) {
		Objects.requireNonNull(userId);
		Objects.requireNonNull(request);
		String name = normalizeNullable(request.name());
		String requestedCity = normalizeNullable(request.serviceCity());
		String serviceCity = requestedCity == null ? DEFAULT_CITY : requestedCity;
		String primaryTrade = normalizeNullable(request.primaryTrade());
		String bio = normalizeNullable(request.bio());

		WorkerProfile profile = repository.findByUserId(userId)
			.orElseGet(() -> WorkerProfile.create(
				userId, name, serviceCity, primaryTrade, request.experienceYears(),
				request.dailyRate(), bio));
		profile.update(name, serviceCity, primaryTrade, request.experienceYears(),
			request.dailyRate(), bio);
		return toResponse(repository.save(profile), phone);
	}

	private WorkerProfileResponse toResponse(WorkerProfile profile, String phone) {
		boolean complete = profile.getName() != null
			&& profile.getServiceCity() != null
			&& profile.getPrimaryTrade() != null
			&& profile.getExperienceYears() != null
			&& profile.getDailyRate() != null
			&& profile.getBio() != null;
		return new WorkerProfileResponse(profile.getUserId(), phone, profile.getName(),
			profile.getServiceCity(), profile.getPrimaryTrade(), profile.getExperienceYears(),
			profile.getDailyRate(), profile.getBio(), complete);
	}

	private WorkerDirectoryResponse toDirectoryResponse(WorkerProfile profile) {
		int caseCount = safeCount(workerCases.countByWorkerUserId(profile.getUserId()));
		int hiredCount = safeCount(
			bookings.countByWorkerUserIdAndStatus(
				profile.getUserId(), BookingStatus.HIRED)
				+ bookings.countByWorkerUserIdAndStatus(
					profile.getUserId(), BookingStatus.COMPLETED));
		return new WorkerDirectoryResponse(profile.getUserId(), profile.getName(),
			profile.getServiceCity(), profile.getPrimaryTrade(), profile.getExperienceYears(),
			profile.getDailyRate(), profile.getBio(), caseCount, hiredCount);
	}

	private int safeCount(long value) {
		return value > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) value;
	}

	private String normalizeNullable(String value) {
		return StringUtils.hasText(value) ? value.trim() : null;
	}
}
