package com.zhidi.server.migration;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.DriverManager;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
class AdminUserMigrationTest {

	@Test
	void v15AssignsAdminRoleToExistingAdminPhoneWithDifferentUserId()
			throws Exception {
		try (MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.4")
				.withDatabaseName("zhidi_test")
				.withUsername("zhidi")
				.withPassword("zhidi_test")) {
			mysql.start();

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.target(MigrationVersion.fromVersion("14"))
				.load()
				.migrate();

			UUID existingAdmin = UUID.randomUUID();
			try (var connection = DriverManager.getConnection(
					mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword());
					var insert = connection.prepareStatement("""
						INSERT INTO users (id, phone, status, created_at, updated_at, version)
						VALUES (UUID_TO_BIN(?), '13800000000', 'ACTIVE', NOW(6), NOW(6), 0)
						""")) {
				insert.setString(1, existingAdmin.toString());
				insert.executeUpdate();
			}

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.load()
				.migrate();

			try (var connection = DriverManager.getConnection(
					mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword());
					var query = connection.prepareStatement("""
						SELECT COUNT(*)
						FROM user_roles
						WHERE user_id = UUID_TO_BIN(?) AND role = 'ADMIN'
						""")) {
				query.setString(1, existingAdmin.toString());
				try (var result = query.executeQuery()) {
					assertThat(result.next()).isTrue();
					assertThat(result.getInt(1)).isEqualTo(1);
				}
			}
		}
	}
}
