package com.zhidi.server.admin;

import java.util.Map;

public record DashboardResponse(
	long totalUsers,
	long newUsersToday,
	long activeBookings,
	Map<String, Long> statusDistribution
) {}
