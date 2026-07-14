package com.zhidi.server.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhidi.server.common.api.TraceIdFilter;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;

class SecurityErrorWriterTest {

	private final ObjectMapper objectMapper = new ObjectMapper();
	private final SecurityErrorWriter writer = new SecurityErrorWriter(objectMapper);

	@AfterEach
	void clearTraceId() {
		MDC.remove(TraceIdFilter.MDC_KEY);
	}

	@Test
	void writesTheSharedJsonEnvelopeWithTraceId() throws Exception {
		MDC.put(TraceIdFilter.MDC_KEY, "trace-security");
		MockHttpServletResponse response = new MockHttpServletResponse();

		writer.write(response, HttpStatus.UNAUTHORIZED,
			"TOKEN_INVALID", "access token invalid");

		JsonNode body = objectMapper.readTree(response.getContentAsString());
		assertThat(response.getStatus()).isEqualTo(401);
		assertThat(MediaType.parseMediaType(response.getContentType()).isCompatibleWith(MediaType.APPLICATION_JSON))
			.isTrue();
		assertThat(response.getCharacterEncoding()).isEqualTo("UTF-8");
		assertThat(body.get("code").asText()).isEqualTo("TOKEN_INVALID");
		assertThat(body.get("message").asText()).isEqualTo("access token invalid");
		assertThat(body.get("data").isNull()).isTrue();
		assertThat(body.get("traceId").asText()).isEqualTo("trace-security");
	}
}
