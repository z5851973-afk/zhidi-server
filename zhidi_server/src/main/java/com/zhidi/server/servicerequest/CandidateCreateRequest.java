package com.zhidi.server.servicerequest;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record CandidateCreateRequest(
	@NotNull UUID workerUserId
) {
}
