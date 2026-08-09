package com.zhidi.server.payment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record WorkerWarrantyAccountResponse(
	UUID id,
	UUID workerUserId,
	BigDecimal effectiveBalance,
	BigDecimal deductedTotal,
	BigDecimal releasedTotal,
	BigDecimal capAmount,
	BigDecimal outstandingAmount,
	WorkerWarrantyAccountStatus status,
	boolean canAcceptNewJobs,
	Instant createdAt,
	Instant updatedAt
) {
	static WorkerWarrantyAccountResponse empty(UUID workerUserId) {
		return new WorkerWarrantyAccountResponse(
			null, workerUserId, WorkerWarrantyAccount.money(BigDecimal.ZERO),
			WorkerWarrantyAccount.money(BigDecimal.ZERO),
			WorkerWarrantyAccount.money(BigDecimal.ZERO),
			WorkerWarrantyAccount.DEFAULT_CAP,
			WorkerWarrantyAccount.money(BigDecimal.ZERO),
			WorkerWarrantyAccountStatus.ACTIVE, true, null, null);
	}

	static WorkerWarrantyAccountResponse from(WorkerWarrantyAccount account,
			BigDecimal outstandingAmount) {
		boolean canAccept = outstandingAmount.compareTo(BigDecimal.ZERO) == 0
			&& account.getStatus() == WorkerWarrantyAccountStatus.ACTIVE;
		return new WorkerWarrantyAccountResponse(
			account.getId(), account.getWorkerUserId(), account.getEffectiveBalance(),
			account.getDeductedTotal(), account.getReleasedTotal(),
			account.getCapAmount(), outstandingAmount, account.getStatus(),
			canAccept, account.getCreatedAt(), account.getUpdatedAt());
	}
}
