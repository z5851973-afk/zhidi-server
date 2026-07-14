package com.zhidi.server.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhidi.server.support.MySqlContainerSupport;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.ImportAutoConfiguration;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnectionAutoConfiguration;

@DataJpaTest
@ImportAutoConfiguration(ServiceConnectionAutoConfiguration.class)
class SmsVerificationCodeRepositoryTest extends MySqlContainerSupport {

	@Autowired
	SmsVerificationCodeRepository repository;

	@Test
	void persistsCountsAndConsumesTheLatestActiveCode() {
		Instant now = Instant.parse("2026-07-14T01:00:00Z");
		repository.saveAndFlush(SmsVerificationCode.issue(
			"13800138000", "digest", "127.0.0.1", now, now.plusSeconds(300)));

		assertThat(repository.countByPhoneAndIssuedAtGreaterThanEqual(
			"13800138000", now.minusSeconds(1))).isEqualTo(1);
		assertThat(repository.countByRequestIpAndIssuedAtGreaterThanEqual(
			"127.0.0.1", now.minusSeconds(1))).isEqualTo(1);

		SmsVerificationCode code = repository
			.findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(
				"13800138000")
			.orElseThrow();
		code.consume(now.plusSeconds(10));
		repository.flush();

		assertThat(code.isActiveAt(now.plusSeconds(11))).isFalse();
	}

	@Test
	void invalidatesExistingActiveCodesForPhone() {
		Instant now = Instant.parse("2026-07-14T01:00:00Z");
		repository.saveAndFlush(SmsVerificationCode.issue(
			"13800138000", "digest", "127.0.0.1", now, now.plusSeconds(300)));

		assertThat(repository.invalidateActiveForPhone("13800138000", now.plusSeconds(1)))
			.isEqualTo(1);
		assertThat(repository
			.findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(
				"13800138000"))
			.isEmpty();
	}
}
