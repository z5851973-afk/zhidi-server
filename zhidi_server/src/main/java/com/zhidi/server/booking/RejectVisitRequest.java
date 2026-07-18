package com.zhidi.server.booking;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RejectVisitRequest(
	@NotBlank(message = "拒绝原因不能为空")
	@Size(max = 300, message = "拒绝原因最多 300 字")
	String reason
) {
}
