package com.zhidi.server.account;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface UserRepository extends JpaRepository<User, UUID>,
		JpaSpecificationExecutor<User> {

	Optional<User> findByPhone(String phone);

	long countByCreatedAtAfter(Instant after);
}
