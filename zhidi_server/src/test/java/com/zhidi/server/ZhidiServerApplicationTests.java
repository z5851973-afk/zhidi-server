package com.zhidi.server;

import com.zhidi.server.account.UserRepository;
import com.zhidi.server.auth.AuthService;
import com.zhidi.server.owner.OwnerProfileService;
import com.zhidi.server.worker.WorkerProfileService;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

@SpringBootTest(properties = {
	"spring.autoconfigure.exclude="
		+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
})
class ZhidiServerApplicationTests {

	@MockitoBean
	AuthService authService;

	@MockitoBean
	OwnerProfileService ownerProfileService;

	@MockitoBean
	WorkerProfileService workerProfileService;

	@MockitoBean
	UserRepository userRepository;

	@Test
	void contextLoads() {
	}

}
