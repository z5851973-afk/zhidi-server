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
		assertThat(html).contains("/api/v1/auth/admin/login");
		assertThat(html).contains("/api/v1/auth/sms-codes");
		assertThat(html).contains("/api/v1/admin/dashboard");
		assertThat(html).contains("待处理售后");
		assertThat(html).contains("冻结质保金");
		assertThat(html).contains("/api/v1/admin/bookings");
		assertThat(html).contains("/api/v1/admin/users");
		assertThat(html).contains("/api/v1/admin/operation-logs");
		assertThat(html).contains("订单查询");
		assertThat(html).contains("用户查询");
		assertThat(html).contains("操作审计");
		assertThat(html).contains("/api/v1/admin/after-sales");
		assertThat(html).contains("/api/v1/admin/warranty-retentions");
		assertThat(html).contains("warrantyDeductionAmount");
	}

	@Test
	void adminPageUsesTheExplicitAfterSaleLifecycleInsteadOfLegacyProcess()
			throws Exception {
		String html = new ClassPathResource("static/admin.html")
			.getContentAsString(StandardCharsets.UTF_8);

		assertThat(html)
			.contains("/accept", "/events", "/resolve", "/close")
			.doesNotContain("/process");
		assertThat(html).contains(
			"id=\"acceptAfterSale\"",
			"id=\"replyAfterSale\"",
			"id=\"resolveAfterSale\"",
			"id=\"closeAfterSale\"");
	}

	@Test
	void adminPageExplainsLifecycleStatusesAndWarrantyDeduction() throws Exception {
		String html = new ClassPathResource("static/admin.html")
			.getContentAsString(StandardCharsets.UTF_8);

		assertThat(html).contains(
			"待平台受理",
			"平台处理中",
			"已解决 · 待关闭",
			"已关闭",
			"扣减质保金金额（可选）",
			"id=\"selectedAfterSaleStatus\"");
	}
}
