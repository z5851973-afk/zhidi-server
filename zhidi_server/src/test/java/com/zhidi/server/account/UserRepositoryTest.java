package com.zhidi.server.account;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhidi.server.support.MySqlContainerSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.ImportAutoConfiguration;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnectionAutoConfiguration;

@DataJpaTest
@ImportAutoConfiguration(ServiceConnectionAutoConfiguration.class)
class UserRepositoryTest extends MySqlContainerSupport {

	@Autowired
	UserRepository repository;

	@Test
	void storesOneAccountWithOwnerAndWorkerRoles() {
		User user = User.create("13800138000");
		user.grantRole(UserRole.OWNER);
		user.grantRole(UserRole.WORKER);
		repository.saveAndFlush(user);

		User loaded = repository.findByPhone("13800138000").orElseThrow();
		assertThat(loaded.hasRole(UserRole.OWNER)).isTrue();
		assertThat(loaded.hasRole(UserRole.WORKER)).isTrue();
	}
}
