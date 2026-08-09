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
class ServiceRequestHouseInfoMigrationTest {

	@Test
	void v30AddsNullableHouseColumnsWithoutChangingHistoricalRequests()
			throws Exception {
		try (MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.4")
				.withDatabaseName("zhidi_test")
				.withUsername("zhidi")
				.withPassword("zhidi_test")) {
			mysql.start();
			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.target(MigrationVersion.fromVersion("29"))
				.load()
				.migrate();

			UUID requestId = UUID.randomUUID();
			try (var connection = DriverManager.getConnection(
					mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())) {
				connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
				try (var insert = connection.prepareStatement("""
					INSERT INTO service_requests (
						id, owner_user_id, trade, service_city, service_address,
						remark, status, version, created_at, updated_at
					) VALUES (
						UUID_TO_BIN(?), UUID_TO_BIN(?), 'painting', '成都市',
						'武侯区科华路 1 号', '历史备注', 'OPEN', 0, NOW(6), NOW(6)
					)
					""")) {
					insert.setString(1, requestId.toString());
					insert.setString(2, UUID.randomUUID().toString());
					insert.executeUpdate();
				}
			}

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.load()
				.migrate();

			try (var connection = DriverManager.getConnection(
					mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword());
					var query = connection.prepareStatement("""
						SELECT remark, area_sqm, bedroom_count, living_room_count,
						       kitchen_count, bathroom_count
						FROM service_requests WHERE id = UUID_TO_BIN(?)
						""")) {
				query.setString(1, requestId.toString());
				try (var result = query.executeQuery()) {
					assertThat(result.next()).isTrue();
					assertThat(result.getString("remark")).isEqualTo("历史备注");
					assertThat(result.getObject("area_sqm")).isNull();
					assertThat(result.getObject("bedroom_count")).isNull();
					assertThat(result.getObject("living_room_count")).isNull();
					assertThat(result.getObject("kitchen_count")).isNull();
					assertThat(result.getObject("bathroom_count")).isNull();
				}
			}
		}
	}
}
