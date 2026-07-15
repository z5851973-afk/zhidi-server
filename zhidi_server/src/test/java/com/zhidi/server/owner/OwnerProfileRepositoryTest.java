package com.zhidi.server.owner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.support.MySqlContainerSupport;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.ImportAutoConfiguration;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnectionAutoConfiguration;
import org.springframework.dao.DataIntegrityViolationException;

@DataJpaTest
@ImportAutoConfiguration(ServiceConnectionAutoConfiguration.class)
class OwnerProfileRepositoryTest extends MySqlContainerSupport {

	@Autowired
	OwnerProfileRepository repository;

	@Autowired
	UserRepository userRepository;

	@Test
	void findsProfileByUserId() {
		User user = userRepository.saveAndFlush(User.create("13800138001"));
		repository.saveAndFlush(OwnerProfile.create(
			user.getId(),
			"李明",
			"成都",
			"旧房改造",
			"武侯区科华路 1 号",
			new BigDecimal("89.50")));

		OwnerProfile loaded = repository.findByUserId(user.getId()).orElseThrow();

		assertThat(loaded.getUserId()).isEqualTo(user.getId());
		assertThat(loaded.getName()).isEqualTo("李明");
		assertThat(loaded.getCity()).isEqualTo("成都");
		assertThat(loaded.getDecorationType()).isEqualTo("旧房改造");
		assertThat(loaded.getAddress()).isEqualTo("武侯区科华路 1 号");
		assertThat(loaded.getArea()).isEqualByComparingTo("89.50");
	}

	@Test
	void rejectsSecondProfileForSameUserId() {
		User user = userRepository.saveAndFlush(User.create("13800138002"));
		repository.saveAndFlush(OwnerProfile.create(
			user.getId(), null, "成都", null, null, null));

		assertThatThrownBy(() -> repository.saveAndFlush(OwnerProfile.create(
			user.getId(), null, "成都", null, null, null)))
			.isInstanceOf(DataIntegrityViolationException.class);
	}
}
