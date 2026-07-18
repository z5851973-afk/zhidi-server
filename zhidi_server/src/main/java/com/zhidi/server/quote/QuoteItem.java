package com.zhidi.server.quote;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.math.BigDecimal;
import java.util.UUID;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record QuoteItem(
	String name,
	BigDecimal quantity,
	String unit,
	BigDecimal unitPrice,
	UUID snapshotCatalogId,
	BigDecimal subtotal,
	// legacy fields kept for backward compatibility
	String tradeName,
	BigDecimal laborFee,
	BigDecimal auxiliaryFee,
	BigDecimal mainMaterialFee
) {

	public static QuoteItem fromCatalog(ServiceCatalog catalog, BigDecimal quantity) {
		BigDecimal unitPrice = catalog.getUnitPrice();
		return new QuoteItem(
			catalog.getName(),
			quantity,
			catalog.getUnit(),
			unitPrice,
			catalog.getId(),
			unitPrice.multiply(quantity),
			null, null, null, null);
	}
}
