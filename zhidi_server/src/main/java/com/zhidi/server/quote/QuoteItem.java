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
		BigDecimal subtotal = unitPrice.multiply(quantity)
			.setScale(2, java.math.RoundingMode.HALF_UP);
		BigDecimal zero = BigDecimal.ZERO.setScale(2);
		return new QuoteItem(
			catalog.getName(),
			quantity,
			catalog.getUnit(),
			unitPrice,
			catalog.getId(),
			subtotal,
			null,
			catalog.isMaterial() ? zero : subtotal,
			catalog.isMaterial() ? subtotal : zero,
			zero);
	}
}
