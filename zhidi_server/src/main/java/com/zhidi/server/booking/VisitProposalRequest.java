package com.zhidi.server.booking;

import jakarta.validation.constraints.NotNull;
import java.time.Instant;

public record VisitProposalRequest(
	@NotNull(message = "上门时间不能为空")
	Instant proposedTime
) {
}
