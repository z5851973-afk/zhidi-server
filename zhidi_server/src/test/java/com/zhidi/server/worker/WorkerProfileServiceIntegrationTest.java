package com.zhidi.server.worker;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import jakarta.validation.Validator;
import java.math.BigDecimal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class WorkerProfileServiceIntegrationTest extends MySqlContainerSupport {

	@Autowired
	WorkerProfileService service;

	@Autowired
	WorkerProfileRepository repository;

	@Autowired
	UserRepository userRepository;

	@Autowired
	Validator validator;

	private User worker;

	@BeforeEach
	void cleanDatabase() {
		repository.deleteAll();
		userRepository.deleteAll();
		worker = userRepository.saveAndFlush(User.create("13800138001"));
	}

	@Test
	void returnsDefaultsWithoutCreatingAProfile() {
		WorkerProfileResponse response = service.get(worker.getId(), worker.getPhone());

		assertThat(response).isEqualTo(new WorkerProfileResponse(
			worker.getId(), worker.getPhone(), null, "成都", null, null, null, null,
			false));
		assertThat(repository.count()).isZero();
	}

	@Test
	void createsThenUpdatesTheSingleProfile() {
		WorkerProfileResponse created = service.update(worker.getId(), worker.getPhone(),
			new WorkerProfileRequest("张师傅", "成都", "水电", 8,
				new BigDecimal("180.00"), "擅长旧房水电改造"));

		assertThat(created.profileComplete()).isTrue();
		assertThat(repository.count()).isEqualTo(1);

		WorkerProfileResponse updated = service.update(worker.getId(), worker.getPhone(),
			new WorkerProfileRequest("王师傅", "绵阳", "泥瓦", 12,
				new BigDecimal("220.00"), "瓷砖铺贴和防水"));

		assertThat(updated.name()).isEqualTo("王师傅");
		assertThat(updated.serviceCity()).isEqualTo("绵阳");
		assertThat(updated.dailyRate()).isEqualByComparingTo("220.00");
		assertThat(repository.count()).isEqualTo(1);
	}

	@Test
	void trimsValuesAndNormalizesBlankCity() {
		WorkerProfileResponse response = service.update(worker.getId(), worker.getPhone(),
			new WorkerProfileRequest("  张师傅  ", "   ", "  水电 ", 8,
				new BigDecimal("180.00"), "  擅长旧房水电改造  "));

		assertThat(response.name()).isEqualTo("张师傅");
		assertThat(response.serviceCity()).isEqualTo("成都");
		assertThat(response.primaryTrade()).isEqualTo("水电");
		assertThat(response.bio()).isEqualTo("擅长旧房水电改造");
		assertThat(service.get(worker.getId(), worker.getPhone())).isEqualTo(response);
	}

	@Test
	void completenessRequiresCoreWorkerValues() {
		assertThat(update("张师傅", "水电", 8, new BigDecimal("180.00"))
			.profileComplete()).isTrue();
		assertThat(update(null, "水电", 8, new BigDecimal("180.00"))
			.profileComplete()).isFalse();
		assertThat(update("张师傅", null, 8, new BigDecimal("180.00"))
			.profileComplete()).isFalse();
		assertThat(update("张师傅", "水电", null, new BigDecimal("180.00"))
			.profileComplete()).isFalse();
		assertThat(update("张师傅", "水电", 8, null)
			.profileComplete()).isFalse();
	}

	@Test
	void validatesLengthsExperienceAndRateBounds() {
		assertThat(validator.validate(new WorkerProfileRequest(
			"x".repeat(81), "x".repeat(81), "x".repeat(41), -1,
			new BigDecimal("100000.001"), "x".repeat(501)))).hasSize(7);
		assertThat(validator.validate(new WorkerProfileRequest(
			null, null, null, 0, new BigDecimal("1.00"), null))).isEmpty();
		assertThat(validator.validate(new WorkerProfileRequest(
			null, null, null, 60, new BigDecimal("99999.99"), null))).isEmpty();
	}

	private WorkerProfileResponse update(String name, String primaryTrade,
			Integer experienceYears, BigDecimal dailyRate) {
		return service.update(worker.getId(), worker.getPhone(),
			new WorkerProfileRequest(name, "成都", primaryTrade, experienceYears,
				dailyRate, null));
	}
}
