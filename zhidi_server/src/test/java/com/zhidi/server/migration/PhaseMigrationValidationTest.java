package com.zhidi.server.migration;

import com.zhidi.server.support.MySqlContainerSupport;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class PhaseMigrationValidationTest extends MySqlContainerSupport {

	@Test
	void applicationContextLoadsWithAllPhaseMigrations() {
		// Context startup validates Flyway migrations and JPA mappings together.
	}
}
