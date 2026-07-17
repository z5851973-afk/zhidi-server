package com.zhidi.server.booking;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public record BookingRequest(
	@NotNull UUID workerUserId,
	@Size(max = 40) String trade,
	@Size(max = 80) String serviceCity,
	@Size(max = 200) String serviceAddress,
	@Size(max = 500) String remark
) {
}
