package com.zhidi.server.inspection;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface InspectionRecordRepository extends JpaRepository<InspectionRecord, UUID> {

	List<InspectionRecord> findByNodeIdOrderByVersionDesc(UUID nodeId);
}
