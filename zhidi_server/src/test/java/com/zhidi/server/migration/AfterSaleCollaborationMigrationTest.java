package com.zhidi.server.migration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
class AfterSaleCollaborationMigrationTest {

	@Test
	void v28ArchivesLegacyDuplicateActiveTicketsBeforeAddingUniqueGuard()
			throws Exception {
		try (MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.4")
				.withDatabaseName("zhidi_test")
				.withUsername("zhidi")
				.withPassword("zhidi_test")) {
			mysql.start();
			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.target(MigrationVersion.fromVersion("27"))
				.load().migrate();

			UUID bookingId = UUID.randomUUID();
			UUID ownerId = UUID.randomUUID();
			UUID workerId = UUID.randomUUID();
			UUID olderTicketId = UUID.randomUUID();
			UUID newerTicketId = UUID.randomUUID();
			try (Connection connection = connection(mysql)) {
				insertUser(connection, ownerId, "13800000001");
				insertUser(connection, workerId, "13800000002");
				connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
				insertBooking(connection, bookingId, ownerId, workerId);
				insertLegacyTicket(connection, olderTicketId, bookingId, ownerId,
					"2026-08-01 10:00:00.000000");
				insertLegacyTicket(connection, newerTicketId, bookingId, ownerId,
					"2026-08-02 10:00:00.000000");
			}

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.load().migrate();

			assertThat(ticketStatuses(mysql, bookingId))
				.containsExactly("CLOSED", "OPEN");
			assertThat(ticketResolution(mysql, olderTicketId))
				.contains("历史重复售后工单已归档");
			assertThat(eventTypes(mysql, olderTicketId))
				.containsExactly("CREATED", "RESOLVED", "CLOSED");
			assertThatThrownBy(() -> insertNewActiveTicket(mysql, bookingId,
				ownerId, workerId)).isInstanceOf(SQLException.class);
		}
	}

	private Connection connection(MySQLContainer<?> mysql) throws SQLException {
		return DriverManager.getConnection(mysql.getJdbcUrl(), mysql.getUsername(),
			mysql.getPassword());
	}

	private void insertUser(Connection connection, UUID id, String phone)
			throws SQLException {
		try (var insert = connection.prepareStatement("""
			INSERT INTO users (
				id, phone, status, version, created_at, updated_at
			) VALUES (UUID_TO_BIN(?), ?, 'ACTIVE', 0, NOW(6), NOW(6))
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, phone);
			insert.executeUpdate();
		}
	}

	private void insertBooking(Connection connection, UUID id, UUID ownerId,
			UUID workerId) throws SQLException {
		try (var insert = connection.prepareStatement("""
			INSERT INTO bookings (
				id, service_request_id, owner_user_id, owner_name, owner_phone,
				worker_user_id, worker_name, trade, service_city, status,
				arrival_confirmed_by_owner, arrival_confirmed_by_worker,
				version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), '业主', '13800000001',
				UUID_TO_BIN(?), '师傅', 'carpentry', '成都', 'COMPLETED',
				TRUE, TRUE, 0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, UUID.randomUUID().toString());
			insert.setString(3, ownerId.toString());
			insert.setString(4, workerId.toString());
			insert.executeUpdate();
		}
	}

	private void insertLegacyTicket(Connection connection, UUID id,
			UUID bookingId, UUID ownerId, String createdAt) throws SQLException {
		try (var insert = connection.prepareStatement("""
			INSERT INTO after_sales (
				id, booking_id, owner_user_id, type, reason, evidence, status,
				version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), 'COMPLAINT',
				'历史问题', JSON_ARRAY(), 'OPEN', 0, ?, ?
			)
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, bookingId.toString());
			insert.setString(3, ownerId.toString());
			insert.setString(4, createdAt);
			insert.setString(5, createdAt);
			insert.executeUpdate();
		}
	}

	private List<String> ticketStatuses(MySQLContainer<?> mysql, UUID bookingId)
			throws SQLException {
		try (Connection connection = connection(mysql);
				var query = connection.prepareStatement("""
					SELECT status FROM after_sales
					WHERE booking_id = UUID_TO_BIN(?) ORDER BY created_at
					""")) {
			query.setString(1, bookingId.toString());
			try (var rows = query.executeQuery()) {
				List<String> statuses = new ArrayList<>();
				while (rows.next()) statuses.add(rows.getString(1));
				return statuses;
			}
		}
	}

	private String ticketResolution(MySQLContainer<?> mysql, UUID ticketId)
			throws SQLException {
		try (Connection connection = connection(mysql);
				var query = connection.prepareStatement("""
					SELECT resolution FROM after_sales WHERE id = UUID_TO_BIN(?)
					""")) {
			query.setString(1, ticketId.toString());
			try (var rows = query.executeQuery()) {
				assertThat(rows.next()).isTrue();
				return rows.getString(1);
			}
		}
	}

	private List<String> eventTypes(MySQLContainer<?> mysql, UUID ticketId)
			throws SQLException {
		try (Connection connection = connection(mysql);
				var query = connection.prepareStatement("""
					SELECT type FROM after_sale_events
					WHERE after_sale_id = UUID_TO_BIN(?) ORDER BY created_at, id
					""")) {
			query.setString(1, ticketId.toString());
			try (var rows = query.executeQuery()) {
				List<String> types = new ArrayList<>();
				while (rows.next()) types.add(rows.getString(1));
				return types;
			}
		}
	}

	private void insertNewActiveTicket(MySQLContainer<?> mysql, UUID bookingId,
			UUID ownerId, UUID workerId) throws SQLException {
		try (Connection connection = connection(mysql);
				var insert = connection.prepareStatement("""
					INSERT INTO after_sales (
						id, booking_id, owner_user_id, worker_user_id, type, reason,
						evidence, status, due_at, last_activity_at, version,
						created_at, updated_at
					) VALUES (
						UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?),
						'COMPLAINT', '重复活动工单', JSON_ARRAY(), 'OPEN',
						DATE_ADD(NOW(6), INTERVAL 72 HOUR), NOW(6), 0, NOW(6), NOW(6)
					)
					""")) {
			insert.setString(1, UUID.randomUUID().toString());
			insert.setString(2, bookingId.toString());
			insert.setString(3, ownerId.toString());
			insert.setString(4, workerId.toString());
			insert.executeUpdate();
		}
	}
}
