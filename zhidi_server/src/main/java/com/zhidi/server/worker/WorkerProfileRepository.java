package com.zhidi.server.worker;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkerProfileRepository extends JpaRepository<WorkerProfile, UUID> {

	Optional<WorkerProfile> findByUserId(UUID userId);

	Optional<WorkerProfile> findByUserIdAndNameIsNotNullAndServiceCityIsNotNullAndPrimaryTradeIsNotNullAndExperienceYearsIsNotNullAndDailyRateIsNotNullAndBioIsNotNull(
		UUID userId);

	java.util.List<WorkerProfile> findByNameIsNotNullAndServiceCityIsNotNullAndPrimaryTradeIsNotNullAndExperienceYearsIsNotNullAndDailyRateIsNotNullAndBioIsNotNullOrderByUpdatedAtDesc();
}
