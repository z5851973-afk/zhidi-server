package com.zhidi.server.migration;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
class InspectionRoundMigrationTest {

	@Test
	void v26BackfillsFailedAndInspectingLegacyRounds() throws Exception {
		try (MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.4")
				.withDatabaseName("zhidi_test")
				.withUsername("zhidi")
				.withPassword("zhidi_test")) {
			mysql.start();
			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.target(MigrationVersion.fromVersion("25"))
				.load().migrate();

			UUID bookingId = UUID.randomUUID();
			UUID workerId = UUID.randomUUID();
			UUID failedNode = UUID.randomUUID();
			UUID duplicateLegacyNode = UUID.randomUUID();
			UUID inspectingNode = UUID.randomUUID();
			try (Connection connection = connection(mysql)) {
				connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
				insertBooking(connection, bookingId, workerId);
				insertNode(connection, failedNode, bookingId, "木工基层验收", "FAILED");
				insertNode(connection, duplicateLegacyNode, bookingId,
					"木工基层验收", "PENDING");
				insertNode(connection, inspectingNode, bookingId, "木工收口验收", "INSPECTING");
				insertRecord(connection, failedNode, 1);
			}

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.load().migrate();

			assertThat(submissionVersions(mysql, failedNode)).containsExactly(1);
			assertThat(submissionVersions(mysql, inspectingNode)).containsExactly(1);
			assertThat(nodeCountByName(mysql, bookingId, "木工基层验收"))
				.isEqualTo(2);
		}
	}

	private Connection connection(MySQLContainer<?> mysql) throws Exception {
		return DriverManager.getConnection(mysql.getJdbcUrl(), mysql.getUsername(),
			mysql.getPassword());
	}

	private void insertBooking(Connection connection, UUID id, UUID workerId)
			throws Exception {
		try (PreparedStatement insert = connection.prepareStatement("""
			INSERT INTO bookings (
				id, service_request_id, owner_user_id, owner_name, owner_phone,
				worker_user_id, worker_name, trade, service_city, status,
				arrival_confirmed_by_owner, arrival_confirmed_by_worker,
				version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), '业主', '13800000000',
				UUID_TO_BIN(?), '师傅', 'carpentry', '成都', 'HIRED', TRUE, TRUE,
				0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, UUID.randomUUID().toString());
			insert.setString(3, UUID.randomUUID().toString());
			insert.setString(4, workerId.toString());
			insert.executeUpdate();
		}
	}

	private void insertNode(Connection connection, UUID id, UUID bookingId,
			String name, String status) throws Exception {
		try (PreparedStatement insert = connection.prepareStatement("""
			INSERT INTO inspection_nodes (
				id, booking_id, name, status, sort_order, version, created_at, updated_at
			) VALUES (UUID_TO_BIN(?), UUID_TO_BIN(?), ?, ?, 1, 0, NOW(6), NOW(6))
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, bookingId.toString());
			insert.setString(3, name);
			insert.setString(4, status);
			insert.executeUpdate();
		}
	}

	private void insertRecord(Connection connection, UUID nodeId, int version)
			throws Exception {
		try (PreparedStatement insert = connection.prepareStatement("""
			INSERT INTO inspection_records (
				id, node_id, inspector_user_id, result, comment, inspection_version,
				version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), 'FAIL', '整改', ?,
				0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, UUID.randomUUID().toString());
			insert.setString(2, nodeId.toString());
			insert.setString(3, UUID.randomUUID().toString());
			insert.setInt(4, version);
			insert.executeUpdate();
		}
	}

	private java.util.List<Integer> submissionVersions(MySQLContainer<?> mysql,
			UUID nodeId) throws Exception {
		try (Connection connection = connection(mysql);
				PreparedStatement query = connection.prepareStatement("""
					SELECT submission_version FROM inspection_submissions
					WHERE node_id = UUID_TO_BIN(?) ORDER BY submission_version
					""")) {
			query.setString(1, nodeId.toString());
			try (var rows = query.executeQuery()) {
				var versions = new java.util.ArrayList<Integer>();
				while (rows.next()) versions.add(rows.getInt(1));
				return versions;
			}
		}
	}

	private int nodeCountByName(MySQLContainer<?> mysql, UUID bookingId,
			String name) throws Exception {
		try (Connection connection = connection(mysql);
				PreparedStatement query = connection.prepareStatement("""
					SELECT COUNT(*) FROM inspection_nodes
					WHERE booking_id = UUID_TO_BIN(?) AND name = ?
					""")) {
			query.setString(1, bookingId.toString());
			query.setString(2, name);
			try (var rows = query.executeQuery()) {
				rows.next();
				return rows.getInt(1);
			}
		}
	}
}
