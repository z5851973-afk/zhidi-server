package com.zhidi.server.quote;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ServiceCatalogRepository extends JpaRepository<ServiceCatalog, UUID> {

	List<ServiceCatalog> findByCategoryInOrderBySortOrderAsc(Collection<String> categories);

	List<ServiceCatalog> findByCategoryOrderBySortOrderAsc(String category);
}
