package com.zhidi.server.inspection;

import jakarta.validation.constraints.NotNull;
import java.util.List;

public record InspectRequest(
		@NotNull(message = "验收结果不能为空")
		InspectionResult result,

		String comment,

		List<String> photos
) {}
