package com.zhidi.server.owner;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhidi.server.support.MySqlContainerSupport;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class OwnerAddressServiceIntegrationTest extends MySqlContainerSupport {

	@Autowired
	JdbcTemplate jdbc;

	@Test
	void migrationCreatesOwnerScopedAddressBookTable() {
		List<String> columns = jdbc.queryForList("""
			SELECT column_name
			FROM information_schema.columns
			WHERE table_schema = DATABASE() AND table_name = 'owner_addresses'
			ORDER BY ordinal_position
			""", String.class);

		assertThat(columns).containsExactly(
			"id", "owner_user_id", "recipient", "phone", "province", "city",
			"district", "detail", "is_default", "version", "created_at", "updated_at");
	}
}
