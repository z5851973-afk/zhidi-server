package com.zhidi.server.quote;

import java.math.BigDecimal;

public record QuoteItem(
	String tradeName,
	BigDecimal laborFee,
	BigDecimal auxiliaryFee,
	BigDecimal mainMaterialFee
) {
}
