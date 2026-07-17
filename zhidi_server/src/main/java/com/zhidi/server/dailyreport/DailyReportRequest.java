package com.zhidi.server.dailyreport;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public record DailyReportRequest(
		@NotBlank(message = "标题不能为空")
		@Size(max = 200, message = "标题最长200字")
		String title,

		@NotBlank(message = "内容不能为空")
		String content,

		List<String> imageUrls
) {}
