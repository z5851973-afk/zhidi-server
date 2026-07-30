package com.zhidi.server.admin;

import java.math.BigDecimal;
import java.util.Map;

public record DashboardResponse(
	long totalUsers,
	long newUsersToday,
	long activeBookings,
	long openAfterSales,
	long pendingWorkerReceipts,
	BigDecimal heldWarrantyAmount,
	BigDecimal paidAmountToday,
	Map<String, Long> statusDistribution
) {}
