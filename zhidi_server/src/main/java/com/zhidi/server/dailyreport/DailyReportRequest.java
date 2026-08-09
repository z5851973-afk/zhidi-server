package com.zhidi.server.dailyreport;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;

public record DailyReportRequest(
		@NotNull(message = "日期不能为空")
		LocalDate reportDate,

		@NotBlank(message = "内容不能为空")
		@Size(max = 2000, message = "日报内容不能超过2000字")
		String content,

		@Size(max = 9, message = "日报照片不能超过9张")
		List<@NotBlank(message = "照片地址不能为空")
			@Size(max = 2048, message = "照片地址过长") String> photos
) {}
