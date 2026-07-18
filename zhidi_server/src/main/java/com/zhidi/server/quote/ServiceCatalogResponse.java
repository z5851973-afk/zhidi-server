package com.zhidi.server.quote;

import java.math.BigDecimal;
import java.util.UUID;

public record ServiceCatalogResponse(
	UUID id,
	String category,
	String name,
	String unit,
	BigDecimal unitPrice,
	boolean isMaterial,
	int sortOrder
) {

	public static ServiceCatalogResponse fromEntity(ServiceCatalog entity) {
		return new ServiceCatalogResponse(
			entity.getId(), entity.getCategory(), entity.getName(),
			entity.getUnit(), entity.getUnitPrice(),
			entity.isMaterial(), entity.getSortOrder());
	}
}
