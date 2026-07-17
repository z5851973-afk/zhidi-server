package com.zhidi.server.worker;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class WorkerProfileServiceTest {

	@Test
	void profileWithoutBioIsNotComplete() {
		UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000003");
		WorkerProfileRepository repository = mock(WorkerProfileRepository.class);
		when(repository.findByUserId(userId)).thenReturn(Optional.empty());
		when(repository.save(any(WorkerProfile.class)))
			.thenAnswer(invocation -> invocation.getArgument(0));
		WorkerProfileService service = new WorkerProfileService(repository);

		WorkerProfileResponse response = service.update(userId, "16600000003",
			new WorkerProfileRequest("张师傅", "成都", "水电", 8,
				new BigDecimal("180.00"), null));

		assertThat(response.profileComplete()).isFalse();
	}
}
