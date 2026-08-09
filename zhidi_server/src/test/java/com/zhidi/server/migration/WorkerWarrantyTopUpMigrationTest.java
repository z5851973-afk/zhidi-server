package com.zhidi.server.migration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
class WorkerWarrantyTopUpMigrationTest {

	@Test
	void v31SupportsOneAfterSaleTopUpObligationWithoutBreakingPaidOrderRows()
			throws Exception {
		try (MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.4")
				.withDatabaseName("zhidi_test")
				.withUsername("zhidi")
				.withPassword("zhidi_test")) {
			mysql.start();
			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.target(MigrationVersion.fromVersion("30"))
				.load()
				.migrate();

			UUID paidContributionId = UUID.randomUUID();
			UUID workerId = UUID.randomUUID();
			try (Connection connection = connection(mysql)) {
				connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
				insertPaidOrderContribution(connection, paidContributionId, workerId);
			}

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.load()
				.migrate();

			assertHistoricalContributionPreserved(mysql, paidContributionId);
			assertNullable(mysql, "payment_order_id");
			assertNullable(mysql, "booking_id");

			UUID afterSaleId = UUID.randomUUID();
			try (Connection connection = connection(mysql)) {
				connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
				insertAfterSaleContribution(
					connection, UUID.randomUUID(), workerId, afterSaleId);
				assertThatThrownBy(() -> insertAfterSaleContribution(
					connection, UUID.randomUUID(), workerId, afterSaleId))
					.isInstanceOf(SQLException.class);
			}
		}
	}

	private Connection connection(MySQLContainer<?> mysql) throws SQLException {
		return DriverManager.getConnection(
			mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword());
	}

	private void insertPaidOrderContribution(Connection connection, UUID id,
			UUID workerId) throws SQLException {
		try (var insert = connection.prepareStatement("""
			INSERT INTO worker_warranty_contributions (
				id, worker_user_id, payment_order_id, booking_id, amount_due,
				status, version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?),
				10.00, 'DUE', 0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, workerId.toString());
			insert.setString(3, UUID.randomUUID().toString());
			insert.setString(4, UUID.randomUUID().toString());
			insert.executeUpdate();
		}
	}

	private void insertAfterSaleContribution(Connection connection, UUID id,
			UUID workerId, UUID afterSaleId) throws SQLException {
		try (var insert = connection.prepareStatement("""
			INSERT INTO worker_warranty_contributions (
				id, worker_user_id, after_sale_id, amount_due,
				status, version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?),
				10.00, 'DUE', 0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, workerId.toString());
			insert.setString(3, afterSaleId.toString());
			insert.executeUpdate();
		}
	}

	private void assertHistoricalContributionPreserved(
			MySQLContainer<?> mysql, UUID id) throws SQLException {
		try (Connection connection = connection(mysql);
				var query = connection.prepareStatement("""
					SELECT payment_order_id, booking_id, after_sale_id
					FROM worker_warranty_contributions WHERE id = UUID_TO_BIN(?)
					""")) {
			query.setString(1, id.toString());
			try (var result = query.executeQuery()) {
				assertThat(result.next()).isTrue();
				assertThat(result.getBytes("payment_order_id")).isNotNull();
				assertThat(result.getBytes("booking_id")).isNotNull();
				assertThat(result.getBytes("after_sale_id")).isNull();
			}
		}
	}

	private void assertNullable(MySQLContainer<?> mysql, String column)
			throws SQLException {
		try (Connection connection = connection(mysql);
				var query = connection.prepareStatement("""
					SELECT is_nullable FROM information_schema.columns
					WHERE table_schema = DATABASE()
					  AND table_name = 'worker_warranty_contributions'
					  AND column_name = ?
					""")) {
			query.setString(1, column);
			try (var result = query.executeQuery()) {
				assertThat(result.next()).isTrue();
				assertThat(result.getString(1)).isEqualTo("YES");
			}
		}
	}
}
