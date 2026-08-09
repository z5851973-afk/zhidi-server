package com.zhidi.server.account;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface UserRepository extends JpaRepository<User, UUID>,
		JpaSpecificationExecutor<User> {

	Optional<User> findByPhone(String phone);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select u from User u where u.id = :id")
	Optional<User> findByIdForUpdate(UUID id);

	long countByCreatedAtAfter(Instant after);
}
