package com.zhidi.server.worker;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.error.BusinessException;
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
		assertThat(update("张师傅", "成都", "水电", 8,
			new BigDecimal("180.00"), "擅长旧房水电改造")
			.profileComplete()).isTrue();
		assertThat(update(null, "成都", "水电", 8,
			new BigDecimal("180.00"), "擅长旧房水电改造")
			.profileComplete()).isFalse();
		assertThat(update("张师傅", null, "水电", 8,
			new BigDecimal("180.00"), "擅长旧房水电改造")
			.profileComplete()).isFalse();
		assertThat(update("张师傅", "成都", null, 8,
			new BigDecimal("180.00"), "擅长旧房水电改造")
			.profileComplete()).isFalse();
		assertThat(update("张师傅", "成都", "水电", null,
			new BigDecimal("180.00"), "擅长旧房水电改造")
			.profileComplete()).isFalse();
		assertThat(update("张师傅", "成都", "水电", 8, null,
			"擅长旧房水电改造")
			.profileComplete()).isFalse();
		assertThat(update("张师傅", "成都", "水电", 8,
			new BigDecimal("180.00"), null)
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

	@Test
	void listsOnlyCompleteWorkerProfilesForDirectory() {
		User complete = createWorker("13800138011");
		User incomplete = createWorker("13800138012");
		service.update(complete.getId(), complete.getPhone(),
			new WorkerProfileRequest("张师傅", "成都", "水电", 8,
				new BigDecimal("180.00"), "擅长旧房水电改造"));
		service.update(incomplete.getId(), incomplete.getPhone(),
			new WorkerProfileRequest("李师傅", "成都", null, 6,
				new BigDecimal("160.00"), null));

		assertThat(service.listVisible()).containsExactly(new WorkerDirectoryResponse(
			complete.getId(), "张师傅", "成都", "水电", 8,
			new BigDecimal("180.00"), "擅长旧房水电改造"));
	}

	@Test
	void getsVisibleWorkerDetailByUserId() {
		service.update(worker.getId(), worker.getPhone(),
			new WorkerProfileRequest("张师傅", "成都", "水电", 8,
				new BigDecimal("180.00"), "擅长旧房水电改造"));

		assertThat(service.getVisible(worker.getId())).isEqualTo(new WorkerDirectoryResponse(
			worker.getId(), "张师傅", "成都", "水电", 8,
			new BigDecimal("180.00"), "擅长旧房水电改造"));
	}

	@Test
	void rejectsMissingOrIncompleteWorkerDetail() {
		assertThat(org.assertj.core.api.Assertions.catchThrowable(() ->
			service.getVisible(worker.getId())))
			.isInstanceOfSatisfying(BusinessException.class,
				error -> assertThat(error.code()).isEqualTo("WORKER_NOT_FOUND"));
	}

	private WorkerProfileResponse update(String name, String serviceCity,
			String primaryTrade, Integer experienceYears, BigDecimal dailyRate,
			String bio) {
		return service.update(worker.getId(), worker.getPhone(),
			new WorkerProfileRequest(name, serviceCity, primaryTrade, experienceYears,
				dailyRate, bio));
	}

	private User createWorker(String phone) {
		User user = User.create(phone);
		user.grantRole(UserRole.WORKER);
		return userRepository.saveAndFlush(user);
	}
}
