package com.zhidi.server.dailyreport;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;
import java.util.List;

public record DailyReportRequest(
		@NotNull(message = "日期不能为空")
		LocalDate reportDate,

		@NotBlank(message = "内容不能为空")
		String content,

		List<String> photos
) {}
