package com.zhidi.server.owner;

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
class OwnerProfileServiceIntegrationTest extends MySqlContainerSupport {

	@Autowired
	OwnerProfileService service;

	@Autowired
	OwnerProfileRepository repository;

	@Autowired
	UserRepository userRepository;

	@Autowired
	Validator validator;

	private User owner;

	@BeforeEach
	void cleanDatabase() {
		repository.deleteAll();
		userRepository.deleteAll();
		owner = userRepository.saveAndFlush(User.create("13800138000"));
	}

	@Test
	void returnsDefaultsWithoutCreatingAProfile() {
		OwnerProfileResponse response = service.get(owner.getId(), owner.getPhone());

		assertThat(response).isEqualTo(new OwnerProfileResponse(
			owner.getId(), owner.getPhone(), null, "成都", null, null, null, false));
		assertThat(repository.count()).isZero();
	}

	@Test
	void createsThenUpdatesTheSingleProfile() {
		OwnerProfileResponse created = service.update(owner.getId(), owner.getPhone(),
			new OwnerProfileRequest("李明", "绵阳", "旧房改造", "科华路 1 号",
				new BigDecimal("89.50")));

		assertThat(created.profileComplete()).isTrue();
		assertThat(repository.count()).isEqualTo(1);

		OwnerProfileResponse updated = service.update(owner.getId(), owner.getPhone(),
			new OwnerProfileRequest("王芳", "成都", "新房装修", "天府大道 2 号",
				new BigDecimal("100.00")));

		assertThat(updated.name()).isEqualTo("王芳");
		assertThat(updated.area()).isEqualByComparingTo("100.00");
		assertThat(repository.count()).isEqualTo(1);
	}

	@Test
	void trimsValuesAndNormalizesBlankValuesAndCity() {
		OwnerProfileResponse response = service.update(owner.getId(), owner.getPhone(),
			new OwnerProfileRequest("  李明  ", "   ", "  旧房改造 ", "  ",
				new BigDecimal("89.50")));

		assertThat(response.name()).isEqualTo("李明");
		assertThat(response.city()).isEqualTo("成都");
		assertThat(response.decorationType()).isEqualTo("旧房改造");
		assertThat(response.address()).isNull();
		assertThat(service.get(owner.getId(), owner.getPhone())).isEqualTo(response);
	}

	@Test
	void completenessRequiresEveryRequiredProfileValue() {
		assertThat(update("李明", "旧房改造", "科华路", new BigDecimal("89.50"))
			.profileComplete()).isTrue();
		assertThat(update(null, "旧房改造", "科华路", new BigDecimal("89.50"))
			.profileComplete()).isFalse();
		assertThat(update("李明", null, "科华路", new BigDecimal("89.50"))
			.profileComplete()).isFalse();
		assertThat(update("李明", "旧房改造", null, new BigDecimal("89.50"))
			.profileComplete()).isFalse();
		assertThat(update("李明", "旧房改造", "科华路", null)
			.profileComplete()).isFalse();
	}

	@Test
	void validatesLengthsAndAreaBoundsAndDigits() {
		assertThat(validator.validate(new OwnerProfileRequest(
			"x".repeat(81), "x".repeat(81), "x".repeat(41), "x".repeat(256),
			new BigDecimal("100000.001")))).hasSize(6);
		assertThat(validator.validate(new OwnerProfileRequest(
			null, null, null, null, new BigDecimal("0.99")))).hasSize(1);
		assertThat(validator.validate(new OwnerProfileRequest(
			null, null, null, null, new BigDecimal("99999.99")))).isEmpty();
	}

	private OwnerProfileResponse update(String name, String decorationType, String address,
			BigDecimal area) {
		return service.update(owner.getId(), owner.getPhone(),
			new OwnerProfileRequest(name, "成都", decorationType, address, area));
	}
}
