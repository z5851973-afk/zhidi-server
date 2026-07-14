package com.zhidi.server;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhidi.server.auth.AuthService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.ResponseEntity;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@SpringBootTest(properties = {
	"spring.autoconfigure.exclude="
		+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
		+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
})
@AutoConfigureMockMvc
@Import(SmokeApiTest.ValidationProbeController.class)
class SmokeApiTest {

	@Autowired
	MockMvc mvc;

	@MockitoBean
	AuthService authService;

	@Test
	void healthResponseCarriesTraceId() throws Exception {
		mvc.perform(get("/actuator/health").header("X-Trace-Id", "test-trace"))
			.andExpect(status().isOk())
			.andExpect(header().string("X-Trace-Id", "test-trace"));
	}

	@Test
	void validationErrorsUseTheSharedEnvelope() throws Exception {
		mvc.perform(post("/api/v1/test/validation")
				.contentType(APPLICATION_JSON)
				.content("{}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
			.andExpect(jsonPath("$.traceId").isNotEmpty());
	}

	@RestController
	static class ValidationProbeController {

		@PostMapping("/api/v1/test/validation")
		ResponseEntity<Void> validate(@Valid @RequestBody ValidationProbeRequest request) {
			return ResponseEntity.noContent().build();
		}
	}

	record ValidationProbeRequest(@NotBlank String name) {
	}
}
