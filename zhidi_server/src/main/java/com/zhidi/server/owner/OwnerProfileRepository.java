package com.zhidi.server.owner;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OwnerProfileRepository extends JpaRepository<OwnerProfile, UUID> {

	Optional<OwnerProfile> findByUserId(UUID userId);
}
