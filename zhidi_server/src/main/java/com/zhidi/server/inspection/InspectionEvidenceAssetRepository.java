package com.zhidi.server.inspection;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface InspectionEvidenceAssetRepository
		extends JpaRepository<InspectionEvidenceAsset, UUID> {

	List<InspectionEvidenceAsset> findByPublicUrlIn(Collection<String> publicUrls);
}
