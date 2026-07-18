package com.zhidi.server.inspection;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;

public record CreateNodeRequest(
		@NotBlank(message = "节点名称不能为空")
		String name,

		String description,

		@PositiveOrZero(message = "排序不能为负数")
		int sortOrder
) {}
