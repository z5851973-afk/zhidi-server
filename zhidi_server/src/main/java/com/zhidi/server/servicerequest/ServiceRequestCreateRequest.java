package com.zhidi.server.servicerequest;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ServiceRequestCreateRequest(
	@NotBlank @Size(max = 40) String trade,
	@NotBlank @Size(max = 80) String serviceCity,
	@Size(max = 200) String serviceAddress,
	@Size(max = 500) String remark
) {
}
