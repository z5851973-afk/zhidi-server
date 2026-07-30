package com.zhidi.server.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;

class AdminStaticPageTest {

	@Test
	void adminPageShipsWithAfterSaleAndWarrantyOperations() throws Exception {
		ClassPathResource page = new ClassPathResource("static/admin.html");

		assertThat(page.exists()).isTrue();
		String html = page.getContentAsString(StandardCharsets.UTF_8);
		assertThat(html).contains("/api/v1/admin/after-sales");
		assertThat(html).contains("/api/v1/admin/warranty-retentions");
		assertThat(html).contains("warrantyDeductionAmount");
	}
}
