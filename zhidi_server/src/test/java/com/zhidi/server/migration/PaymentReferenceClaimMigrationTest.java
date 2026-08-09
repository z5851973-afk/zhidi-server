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
class PaymentReferenceClaimMigrationTest {

	@Test
	void v33BackfillsBothComponentsAndEnforcesOneGlobalReferenceOwner()
			throws Exception {
		try (MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.4")
				.withDatabaseName("zhidi_test")
				.withUsername("zhidi")
				.withPassword("zhidi_test")) {
			mysql.start();
			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.target(MigrationVersion.fromVersion("32"))
				.load()
				.migrate();

			UUID constructionOrderId = UUID.randomUUID();
			UUID platformOrderId = UUID.randomUUID();
			try (Connection connection = connection(mysql)) {
				connection.createStatement().execute("SET FOREIGN_KEY_CHECKS = 0");
				insertOrder(connection, constructionOrderId,
					"migration-construction-ref", null);
				insertOrder(connection, platformOrderId,
					null, "migration-platform-ref");
			}

			Flyway.configure()
				.dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
				.locations("classpath:db/migration")
				.load()
				.migrate();

			assertClaim(mysql, "migration-construction-ref",
				constructionOrderId, "CONSTRUCTION");
			assertClaim(mysql, "migration-platform-ref",
				platformOrderId, "PLATFORM_FEE");
			assertThatThrownBy(() -> insertClaim(mysql,
				"migration-construction-ref", platformOrderId, "PLATFORM_FEE"))
				.isInstanceOf(SQLException.class);
		}
	}

	private static Connection connection(MySQLContainer<?> mysql)
			throws SQLException {
		return DriverManager.getConnection(
			mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword());
	}

	private static void insertOrder(Connection connection, UUID orderId,
			String constructionReference, String platformReference)
			throws SQLException {
		try (var insert = connection.prepareStatement("""
			INSERT INTO payment_orders (
				id, booking_id, owner_user_id, worker_user_id,
				amount, platform_fee, worker_settlement,
				funding_model, quote_amount,
				construction_payment_status, platform_fee_status, status,
				payment_method, construction_payment_channel,
				construction_payment_reference, platform_fee_channel,
				platform_fee_reference, version, created_at, updated_at
			) VALUES (
				UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?), UUID_TO_BIN(?),
				1100.00, 100.00, 1000.00,
				'OFFLINE_SPLIT_V2', 1000.00,
				?, ?, 'PARTIALLY_REPORTED',
				'OFFLINE_SPLIT', ?, ?, ?, ?, 0, NOW(6), NOW(6)
			)
			""")) {
			insert.setString(1, orderId.toString());
			insert.setString(2, UUID.randomUUID().toString());
			insert.setString(3, UUID.randomUUID().toString());
			insert.setString(4, UUID.randomUUID().toString());
			insert.setString(5,
				constructionReference == null ? "NOT_REPORTED" : "REPORTED");
			insert.setString(6,
				platformReference == null ? "NOT_REPORTED" : "REPORTED");
			insert.setString(7,
				constructionReference == null ? null : "BANK_TRANSFER");
			insert.setString(8, constructionReference);
			insert.setString(9,
				platformReference == null ? null : "CORPORATE_TRANSFER");
			insert.setString(10, platformReference);
			insert.executeUpdate();
		}
	}

	private static void assertClaim(MySQLContainer<?> mysql, String reference,
			UUID orderId, String component) throws SQLException {
		try (Connection connection = connection(mysql);
				var query = connection.prepareStatement("""
					SELECT BIN_TO_UUID(payment_order_id), component
					FROM payment_reference_claims
					WHERE payment_reference = ?
					""")) {
			query.setString(1, reference);
			try (var result = query.executeQuery()) {
				assertThat(result.next()).isTrue();
				assertThat(result.getString(1)).isEqualToIgnoringCase(orderId.toString());
				assertThat(result.getString(2)).isEqualTo(component);
				assertThat(result.next()).isFalse();
			}
		}
	}

	private static void insertClaim(MySQLContainer<?> mysql, String reference,
			UUID orderId, String component) throws SQLException {
		try (Connection connection = connection(mysql);
				var insert = connection.prepareStatement("""
					INSERT INTO payment_reference_claims (
						payment_reference, payment_order_id, component, created_at
					) VALUES (?, UUID_TO_BIN(?), ?, NOW(6))
					""")) {
			insert.setString(1, reference);
			insert.setString(2, orderId.toString());
			insert.setString(3, component);
			insert.executeUpdate();
		}
	}
}
