package com.zhidi.server.booking;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record BookingCancellationRequest(
	@NotBlank(message = "取消原因不能为空")
	@Size(max = 300, message = "取消原因最多 300 字")
	String reason
) {
}
