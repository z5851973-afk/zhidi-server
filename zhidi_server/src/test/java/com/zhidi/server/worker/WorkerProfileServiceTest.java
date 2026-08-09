package com.zhidi.server.worker;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.workercase.WorkerCaseRepository;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class WorkerProfileServiceTest {

	@Test
	void profileWithoutBioIsNotComplete() {
		UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000003");
		WorkerProfileRepository repository = mock(WorkerProfileRepository.class);
		WorkerCaseRepository workerCases = mock(WorkerCaseRepository.class);
		BookingRepository bookings = mock(BookingRepository.class);
		when(repository.findByUserId(userId)).thenReturn(Optional.empty());
		when(repository.save(any(WorkerProfile.class)))
			.thenAnswer(invocation -> invocation.getArgument(0));
		WorkerProfileService service = new WorkerProfileService(repository,
			workerCases, bookings);

		WorkerProfileResponse response = service.update(userId, "16600000003",
			new WorkerProfileRequest("张师傅", "成都", "水电", 8,
				new BigDecimal("180.00"), null));

		assertThat(response.profileComplete()).isFalse();
	}

	@Test
	void visibleDirectoryIncludesRealTrustStats() {
		UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000004");
		WorkerProfileRepository repository = mock(WorkerProfileRepository.class);
		WorkerCaseRepository workerCases = mock(WorkerCaseRepository.class);
		BookingRepository bookings = mock(BookingRepository.class);
		WorkerProfile profile = WorkerProfile.create(userId, "张师傅", "成都",
			"水电", 8, new BigDecimal("180.00"), "擅长旧房水电改造");
		when(repository
			.findByNameIsNotNullAndServiceCityIsNotNullAndPrimaryTradeIsNotNullAndExperienceYearsIsNotNullAndDailyRateIsNotNullAndBioIsNotNullOrderByUpdatedAtDesc())
			.thenReturn(List.of(profile));
		when(workerCases.countByWorkerUserId(userId)).thenReturn(2L);
		when(bookings.countByWorkerUserIdAndStatus(userId, BookingStatus.HIRED))
			.thenReturn(1L);

		WorkerProfileService service = new WorkerProfileService(repository,
			workerCases, bookings);

		assertThat(service.listVisible()).containsExactly(new WorkerDirectoryResponse(
			userId, "张师傅", "成都", "水电", 8, new BigDecimal("180.00"),
			"擅长旧房水电改造", 2, 1));
	}
}
