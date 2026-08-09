package com.zhidi.server.quote;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class QuoteItemTest {

	@Test
	void catalogLaborItemSnapshotsSubtotalAsLaborFee() {
		ServiceCatalog catalog = new ServiceCatalog(
			"PAINTING", "墙面刷漆", "平米", new BigDecimal("40.00"), false, 1);

		QuoteItem item = QuoteItem.fromCatalog(catalog, new BigDecimal("15"));

		assertThat(item.subtotal()).isEqualByComparingTo("600.00");
		assertThat(item.laborFee()).isEqualByComparingTo("600.00");
		assertThat(item.auxiliaryFee()).isEqualByComparingTo("0.00");
		assertThat(item.mainMaterialFee()).isEqualByComparingTo("0.00");
	}

	@Test
	void catalogMaterialItemSnapshotsSubtotalAsMaterialFee() {
		ServiceCatalog catalog = new ServiceCatalog(
			"PAINTING", "乳胶漆材料", "桶", new BigDecimal("300.00"), true, 10);

		QuoteItem item = QuoteItem.fromCatalog(catalog, new BigDecimal("6"));

		assertThat(item.subtotal()).isEqualByComparingTo("1800.00");
		assertThat(item.laborFee()).isEqualByComparingTo("0.00");
		assertThat(item.auxiliaryFee()).isEqualByComparingTo("1800.00");
		assertThat(item.mainMaterialFee()).isEqualByComparingTo("0.00");
	}
}
