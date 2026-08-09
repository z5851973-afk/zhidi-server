package com.zhidi.server.migration;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
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
class SplitPaymentWarrantyMigrationTest {

	@Test
	void v24KeepsLegacyAmountsAndCreatesUniqueWorkerWarrantyLedgers()
			throws Exception {
		try (MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.4")
				.withDatabaseName("zhidi_test")
				.withUsername("zhidi")
				.withPassword("zhidi_test")) {
			mysql.start();
			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.target(MigrationVersion.fromVersion("23"))
				.load()
				.migrate();

			UUID legacyOrderId = UUID.randomUUID();
			UUID workerId = UUID.randomUUID();
			try (Connection connection = connection(mysql)) {
				connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
				insertLegacyOrder(connection, legacyOrderId, workerId);
			}

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.load()
				.migrate();

			assertLegacyOrderUnchanged(mysql, legacyOrderId);
			assertThat(tableExists(mysql, "worker_warranty_accounts")).isTrue();
			assertThat(tableExists(mysql, "worker_warranty_contributions")).isTrue();
			assertThat(tableExists(mysql, "worker_warranty_ledger_entries")).isTrue();
			assertUniqueWorkerAccount(mysql, workerId);
			assertUniquePaymentOrderContribution(mysql, legacyOrderId, workerId);
		}
	}

	private Connection connection(MySQLContainer<?> mysql) throws SQLException {
		return DriverManager.getConnection(
			mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword());
	}

	private void insertLegacyOrder(Connection connection, UUID orderId,
			UUID workerId) throws SQLException {
		try (var insert = connection.prepareStatement("""
			INSERT INTO payment_orders (
				id, booking_id, owner_user_id, worker_user_id,
				amount, platform_fee, worker_settlement, status,
				payment_method, version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?),
				6380.00, 580.00, 5220.00, 'PAID',
				'OFFLINE', 0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, orderId.toString());
			insert.setString(2, UUID.randomUUID().toString());
			insert.setString(3, UUID.randomUUID().toString());
			insert.setString(4, workerId.toString());
			insert.executeUpdate();
		}
	}

	private void assertLegacyOrderUnchanged(MySQLContainer<?> mysql, UUID orderId)
			throws SQLException {
		try (Connection connection = connection(mysql);
				var query = connection.prepareStatement("""
					SELECT funding_model, amount, platform_fee, worker_settlement
					FROM payment_orders WHERE id = UUID_TO_BIN(?)
					""")) {
			query.setString(1, orderId.toString());
			try (var result = query.executeQuery()) {
				assertThat(result.next()).isTrue();
				assertThat(result.getString("funding_model"))
					.isEqualTo("LEGACY_OWNER_RETENTION");
				assertThat(result.getBigDecimal("amount"))
					.isEqualByComparingTo("6380.00");
				assertThat(result.getBigDecimal("platform_fee"))
					.isEqualByComparingTo("580.00");
				assertThat(result.getBigDecimal("worker_settlement"))
					.isEqualByComparingTo("5220.00");
			}
		}
	}

	private boolean tableExists(MySQLContainer<?> mysql, String table)
			throws SQLException {
		try (Connection connection = connection(mysql);
				var query = connection.prepareStatement("""
					SELECT COUNT(*) FROM information_schema.tables
					WHERE table_schema = DATABASE() AND table_name = ?
					""")) {
			query.setString(1, table);
			try (var result = query.executeQuery()) {
				result.next();
				return result.getInt(1) == 1;
			}
		}
	}

	private void assertUniqueWorkerAccount(MySQLContainer<?> mysql, UUID workerId)
			throws SQLException {
		try (Connection connection = connection(mysql)) {
			connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
			insertWarrantyAccount(connection, UUID.randomUUID(), workerId);
			org.assertj.core.api.Assertions.assertThatThrownBy(() ->
				insertWarrantyAccount(connection, UUID.randomUUID(), workerId))
				.isInstanceOf(SQLException.class);
		}
	}

	private void insertWarrantyAccount(Connection connection, UUID id,
			UUID workerId) throws SQLException {
		try (var insert = connection.prepareStatement("""
			INSERT INTO worker_warranty_accounts (
				id, worker_user_id, effective_balance, deducted_total,
				released_total, cap_amount, status, version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), 0, 0, 0, 10000,
				'ACTIVE', 0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, workerId.toString());
			insert.executeUpdate();
		}
	}

	private void assertUniquePaymentOrderContribution(MySQLContainer<?> mysql,
			UUID paymentOrderId, UUID workerId) throws SQLException {
		try (Connection connection = connection(mysql)) {
			connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
			insertContribution(connection, UUID.randomUUID(), paymentOrderId, workerId);
			org.assertj.core.api.Assertions.assertThatThrownBy(() ->
				insertContribution(connection, UUID.randomUUID(), paymentOrderId, workerId))
				.isInstanceOf(SQLException.class);
		}
	}

	private void insertContribution(Connection connection, UUID id,
			UUID paymentOrderId, UUID workerId) throws SQLException {
		try (var insert = connection.prepareStatement("""
			INSERT INTO worker_warranty_contributions (
				id, worker_user_id, payment_order_id, booking_id, amount_due,
				status, version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?),
				100.00, 'DUE', 0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, id.toString());
			insert.setString(2, workerId.toString());
			insert.setString(3, paymentOrderId.toString());
			insert.setString(4, UUID.randomUUID().toString());
			insert.executeUpdate();
		}
	}
}
