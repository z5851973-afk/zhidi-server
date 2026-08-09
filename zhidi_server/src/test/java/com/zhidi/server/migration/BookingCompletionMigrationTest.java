package com.zhidi.server.migration;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.sql.DriverManager;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
class BookingCompletionMigrationTest {

	@Test
	void v22CompletesOnlyHiredBookingsWhoseCurrentTradeNodesAllPassed()
			throws Exception {
		try (MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.4")
				.withDatabaseName("zhidi_test")
				.withUsername("zhidi")
				.withPassword("zhidi_test")) {
			mysql.start();
			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.target(MigrationVersion.fromVersion("21"))
				.load()
				.migrate();

			UUID completed = UUID.randomUUID();
			UUID stillHired = UUID.randomUUID();
			try (Connection connection = DriverManager.getConnection(
					mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())) {
				connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
				insertBooking(connection, completed, "carpentry");
				insertNode(connection, completed, "木工验收", "PASSED");
				insertNode(connection, completed, "油漆验收", "PENDING");
				insertBooking(connection, stillHired, "painting");
				insertNode(connection, stillHired, "油漆验收", "INSPECTING");
			}

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.load()
				.migrate();

			assertStatus(mysql, completed, "COMPLETED");
			assertStatus(mysql, stillHired, "HIRED");
		}
	}

	private void insertBooking(Connection connection, UUID id, String trade)
			throws Exception {
		try (var insert = connection.prepareStatement("""
			INSERT INTO bookings (
				id, service_request_id, owner_user_id, owner_name, owner_phone,
				worker_user_id, worker_name, trade, service_city, status,
				arrival_confirmed_by_owner, arrival_confirmed_by_worker,
				version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), '业主', '13800000000',
				UUID_TO_BIN(?), '师傅', ?, '成都', 'HIRED', TRUE, TRUE,
				0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, UUID.randomUUID().toString());
			insert.setString(3, UUID.randomUUID().toString());
			insert.setString(4, UUID.randomUUID().toString());
			insert.setString(5, trade);
			insert.executeUpdate();
		}
	}

	private void insertNode(Connection connection, UUID bookingId,
			String name, String status) throws Exception {
		try (var insert = connection.prepareStatement("""
			INSERT INTO inspection_nodes (
				id, booking_id, name, status, sort_order, version, created_at, updated_at
			) VALUES (UUID_TO_BIN(?), UUID_TO_BIN(?), ?, ?, 1, 0, NOW(6), NOW(6))
			""")) {
			insert.setString(1, UUID.randomUUID().toString());
			insert.setString(2, bookingId.toString());
			insert.setString(3, name);
			insert.setString(4, status);
			insert.executeUpdate();
		}
	}

	private void assertStatus(MySQLContainer<?> mysql, UUID bookingId,
			String expected) throws Exception {
		try (Connection connection = DriverManager.getConnection(
				mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword());
				var query = connection.prepareStatement(
					"SELECT status FROM bookings WHERE id = UUID_TO_BIN(?)")) {
			query.setString(1, bookingId.toString());
			try (var result = query.executeQuery()) {
				assertThat(result.next()).isTrue();
				assertThat(result.getString("status")).isEqualTo(expected);
			}
		}
	}
}
