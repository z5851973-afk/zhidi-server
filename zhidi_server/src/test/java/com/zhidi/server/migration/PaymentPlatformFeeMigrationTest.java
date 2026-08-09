package com.zhidi.server.migration;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.sql.DriverManager;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
class PaymentPlatformFeeMigrationTest {

	@Test
	void v21BackfillsOnlyOfflineOrdersMatchingTheLegacyAmountFingerprint()
			throws Exception {
		try (MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.4")
				.withDatabaseName("zhidi_test")
				.withUsername("zhidi")
				.withPassword("zhidi_test")) {
			mysql.start();

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.target(MigrationVersion.fromVersion("20"))
				.load()
				.migrate();

			UUID legacyOrderId = UUID.randomUUID();
			UUID modernOrderId = UUID.randomUUID();
			try (var connection = DriverManager.getConnection(
					mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())) {
				try (var disableForeignKeys = connection.createStatement()) {
					disableForeignKeys.execute("SET FOREIGN_KEY_CHECKS = 0");
				}
				insertOrder(connection, legacyOrderId,
					new BigDecimal("5800.00"), BigDecimal.ZERO,
					new BigDecimal("5220.00"));
				insertOrder(connection, modernOrderId,
					new BigDecimal("6380.00"), new BigDecimal("580.00"),
					new BigDecimal("5220.00"));
			}

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.load()
				.migrate();

			assertOrderAmounts(mysql, legacyOrderId, "6380.00", "580.00", "5220.00");
			assertOrderAmounts(mysql, modernOrderId, "6380.00", "580.00", "5220.00");
		}
	}

	private void insertOrder(java.sql.Connection connection, UUID orderId,
			BigDecimal amount, BigDecimal platformFee,
			BigDecimal workerSettlement) throws Exception {
		try (var insert = connection.prepareStatement("""
			INSERT INTO payment_orders (
				id, booking_id, owner_user_id, worker_user_id,
				amount, platform_fee, worker_settlement, status,
				payment_method, version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?),
				?, ?, ?, 'PAID', 'OFFLINE', 0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, orderId.toString());
			insert.setString(2, UUID.randomUUID().toString());
			insert.setString(3, UUID.randomUUID().toString());
			insert.setString(4, UUID.randomUUID().toString());
			insert.setBigDecimal(5, amount);
			insert.setBigDecimal(6, platformFee);
			insert.setBigDecimal(7, workerSettlement);
			insert.executeUpdate();
		}
	}

	private void assertOrderAmounts(MySQLContainer<?> mysql, UUID orderId,
			String expectedAmount, String expectedFee, String expectedSettlement)
			throws Exception {
		try (var connection = DriverManager.getConnection(
				mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword());
				var query = connection.prepareStatement("""
					SELECT amount, platform_fee, worker_settlement
					FROM payment_orders
					WHERE id = UUID_TO_BIN(?)
					""")) {
			query.setString(1, orderId.toString());
			try (var result = query.executeQuery()) {
				assertThat(result.next()).isTrue();
				assertThat(result.getBigDecimal("amount"))
					.isEqualByComparingTo(expectedAmount);
				assertThat(result.getBigDecimal("platform_fee"))
					.isEqualByComparingTo(expectedFee);
				assertThat(result.getBigDecimal("worker_settlement"))
					.isEqualByComparingTo(expectedSettlement);
			}
		}
	}
}
