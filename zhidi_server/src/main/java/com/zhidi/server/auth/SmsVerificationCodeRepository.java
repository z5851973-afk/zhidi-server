package com.zhidi.server.auth;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SmsVerificationCodeRepository extends JpaRepository<SmsVerificationCode, UUID> {

	long countByPhoneAndIssuedAtGreaterThanEqual(String phone, Instant since);

	long countByRequestIpAndIssuedAtGreaterThanEqual(String requestIp, Instant since);

	Optional<SmsVerificationCode> findTopByPhoneOrderByIssuedAtDesc(String phone);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	Optional<SmsVerificationCode>
		findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(String phone);

	@Modifying(clearAutomatically = true, flushAutomatically = true)
	@Query("""
		update SmsVerificationCode c set c.invalidatedAt = :now
		where c.phone = :phone and c.consumedAt is null and c.invalidatedAt is null
		""")
	int invalidateActiveForPhone(@Param("phone") String phone, @Param("now") Instant now);
}
