package com.zhidi.server.notification;

import java.util.List;

public record BusinessEventPageResponse(
		List<BusinessEventResponse> items,
		long nextCursor) {

	public BusinessEventPageResponse {
		items = List.copyOf(items);
	}
}
