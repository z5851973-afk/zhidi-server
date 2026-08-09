package com.zhidi.server.booking;

import java.util.Set;

public enum BookingStatus {
	PENDING,
	ACCEPTED,
	VISIT_PROPOSED,
	VISIT_SCHEDULED,
	ARRIVAL_PENDING,
	ON_SITE,
	QUOTE_PENDING,
	READY_TO_START,
	REJECTED,
	CANCELLED,
	NOT_SELECTED,
	HIRED,
	COMPLETED;

	public static final Set<BookingStatus> CANDIDATE_TERMINAL_STATUSES = Set.of(
		REJECTED,
		CANCELLED,
		NOT_SELECTED,
		HIRED,
		COMPLETED);
}
