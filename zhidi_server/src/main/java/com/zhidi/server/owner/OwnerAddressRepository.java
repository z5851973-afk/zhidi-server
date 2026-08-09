package com.zhidi.server.owner;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OwnerAddressRepository extends JpaRepository<OwnerAddress, UUID> {

	List<OwnerAddress> findByOwnerUserIdOrderByDefaultAddressDescUpdatedAtDesc(UUID ownerUserId);

	Optional<OwnerAddress> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);

	Optional<OwnerAddress> findFirstByOwnerUserIdAndIdNotOrderByUpdatedAtDesc(
		UUID ownerUserId, UUID id);
}
