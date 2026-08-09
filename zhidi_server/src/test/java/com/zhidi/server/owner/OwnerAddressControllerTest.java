package com.zhidi.server.owner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhidi.server.account.User;
import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.auth.JwtTokenService;
import com.zhidi.server.support.MySqlContainerSupport;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class OwnerAddressControllerTest extends MySqlContainerSupport {

	@Autowired MockMvc mvc;
	@Autowired ObjectMapper objectMapper;
	@Autowired JwtTokenService tokens;
	@Autowired UserRepository users;
	@Autowired JdbcTemplate jdbc;

	private User owner;
	private User otherOwner;

	@BeforeEach
	void cleanDatabase() {
		jdbc.update("DELETE FROM owner_addresses");
		users.deleteAll();
		owner = createOwner("13800138201");
		otherOwner = createOwner("13800138202");
	}

	@Test
	void crudMaintainsExactlyOneDefaultAddress() throws Exception {
		String firstId = createAddress(owner, "林先生", "13800138201", "四川省",
			"成都市", "武侯区", "科华路 1 号", false);
		String secondId = createAddress(owner, "王女士", "13900139000", "四川省",
			"成都市", "高新区", "天府大道 2 号", false);

		mvc.perform(get("/api/v1/owners/me/addresses").header("Authorization", token(owner)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.length()").value(2))
			.andExpect(jsonPath("$.data[0].id").value(firstId))
			.andExpect(jsonPath("$.data[0].isDefault").value(true))
			.andExpect(jsonPath("$.data[1].id").value(secondId))
			.andExpect(jsonPath("$.data[1].isDefault").value(false));

		mvc.perform(put("/api/v1/owners/me/addresses/{id}/default", secondId)
				.header("Authorization", token(owner)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.id").value(secondId))
			.andExpect(jsonPath("$.data.isDefault").value(true));

		mvc.perform(put("/api/v1/owners/me/addresses/{id}", secondId)
				.header("Authorization", token(owner))
				.contentType(APPLICATION_JSON)
				.content(addressJson("王女士", "13900139000", "四川省", "成都市",
					"锦江区", "红星路 3 号", true)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.district").value("锦江区"))
			.andExpect(jsonPath("$.data.detail").value("红星路 3 号"));

		mvc.perform(delete("/api/v1/owners/me/addresses/{id}", secondId)
				.header("Authorization", token(owner)))
			.andExpect(status().isOk());

		mvc.perform(get("/api/v1/owners/me/addresses").header("Authorization", token(owner)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data.length()").value(1))
			.andExpect(jsonPath("$.data[0].id").value(firstId))
			.andExpect(jsonPath("$.data[0].isDefault").value(true));

		mvc.perform(delete("/api/v1/owners/me/addresses/{id}", firstId)
				.header("Authorization", token(owner)))
			.andExpect(status().isOk());

		mvc.perform(get("/api/v1/owners/me/addresses").header("Authorization", token(owner)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data").isEmpty());
	}

	@Test
	void otherOwnerCannotReadOrMutateAddressById() throws Exception {
		String id = createAddress(owner, "林先生", "13800138201", "四川省", "成都市",
			"武侯区", "科华路 1 号", true);

		mvc.perform(put("/api/v1/owners/me/addresses/{id}/default", id)
				.header("Authorization", token(otherOwner)))
			.andExpect(status().isNotFound())
			.andExpect(jsonPath("$.code").value("OWNER_ADDRESS_NOT_FOUND"));
		mvc.perform(delete("/api/v1/owners/me/addresses/{id}", id)
				.header("Authorization", token(otherOwner)))
			.andExpect(status().isNotFound())
			.andExpect(jsonPath("$.code").value("OWNER_ADDRESS_NOT_FOUND"));

		mvc.perform(get("/api/v1/owners/me/addresses")
				.header("Authorization", token(otherOwner)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.data").isEmpty());
	}

	@Test
	void invalidAddressFieldsReturnValidationError() throws Exception {
		mvc.perform(post("/api/v1/owners/me/addresses")
				.header("Authorization", token(owner))
				.contentType(APPLICATION_JSON)
				.content(addressJson("", "123", "", "", "", "", false)))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM owner_addresses", Long.class))
			.isZero();
	}

	private String createAddress(User user, String recipient, String phone, String province,
			String city, String district, String detail, boolean isDefault) throws Exception {
		MvcResult result = mvc.perform(post("/api/v1/owners/me/addresses")
				.header("Authorization", token(user))
				.contentType(APPLICATION_JSON)
				.content(addressJson(recipient, phone, province, city, district, detail, isDefault)))
			.andExpect(status().isCreated())
			.andReturn();
		JsonNode root = objectMapper.readTree(result.getResponse().getContentAsByteArray());
		return root.path("data").path("id").asText();
	}

	private String addressJson(String recipient, String phone, String province, String city,
			String district, String detail, boolean isDefault) throws Exception {
		return objectMapper.writeValueAsString(new AddressPayload(
			recipient, phone, province, city, district, detail, isDefault));
	}

	private String token(User user) {
		return "Bearer " + tokens.issue(user.getId(), user.getPhone(), Set.of(UserRole.OWNER))
			.accessToken();
	}

	private User createOwner(String phone) {
		User user = User.create(phone);
		user.grantRole(UserRole.OWNER);
		return users.saveAndFlush(user);
	}

	private record AddressPayload(String recipient, String phone, String province,
		String city, String district, String detail, boolean isDefault) {}
}
