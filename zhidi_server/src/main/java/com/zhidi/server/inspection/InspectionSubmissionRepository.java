package com.zhidi.server.inspection;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface InspectionSubmissionRepository
		extends JpaRepository<InspectionSubmission, UUID> {

	List<InspectionSubmission> findByNodeIdOrderBySubmissionVersionAsc(UUID nodeId);
}
