package com.zhidi.server.payment;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "worker_warranty_accounts")
public class WorkerWarrantyAccount extends BaseEntity {

	public static final BigDecimal DEFAULT_CAP = new BigDecimal("10000.00");

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, unique = true,
		updatable = false, columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@Column(name = "effective_balance", nullable = false, precision = 12, scale = 2)
	private BigDecimal effectiveBalance;

	@Column(name = "deducted_total", nullable = false, precision = 12, scale = 2)
	private BigDecimal deductedTotal;

	@Column(name = "released_total", nullable = false, precision = 12, scale = 2)
	private BigDecimal releasedTotal;

	@Column(name = "cap_amount", nullable = false, precision = 12, scale = 2)
	private BigDecimal capAmount;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private WorkerWarrantyAccountStatus status;

	protected WorkerWarrantyAccount() {}

	private WorkerWarrantyAccount(UUID workerUserId) {
		this.workerUserId = Objects.requireNonNull(workerUserId);
		this.effectiveBalance = money(BigDecimal.ZERO);
		this.deductedTotal = money(BigDecimal.ZERO);
		this.releasedTotal = money(BigDecimal.ZERO);
		this.capAmount = DEFAULT_CAP;
		this.status = WorkerWarrantyAccountStatus.ACTIVE;
	}

	public static WorkerWarrantyAccount create(UUID workerUserId) {
		return new WorkerWarrantyAccount(workerUserId);
	}

	public void credit(BigDecimal amount) {
		BigDecimal normalized = positive(amount);
		BigDecimal next = effectiveBalance.add(normalized);
		if (next.compareTo(capAmount) > 0) {
			throw new IllegalArgumentException("质保金余额不能超过上限");
		}
		effectiveBalance = money(next);
	}

	public void deduct(BigDecimal amount) {
		BigDecimal normalized = positive(amount);
		if (normalized.compareTo(effectiveBalance) > 0) {
			throw new IllegalArgumentException("质保金余额不足");
		}
		effectiveBalance = money(effectiveBalance.subtract(normalized));
		deductedTotal = money(deductedTotal.add(normalized));
		status = WorkerWarrantyAccountStatus.TOP_UP_REQUIRED;
	}

	public BigDecimal releaseAll() {
		BigDecimal released = effectiveBalance;
		effectiveBalance = money(BigDecimal.ZERO);
		releasedTotal = money(releasedTotal.add(released));
		status = WorkerWarrantyAccountStatus.RELEASED;
		return released;
	}

	public void requireTopUp() {
		if (status != WorkerWarrantyAccountStatus.RELEASED) {
			status = WorkerWarrantyAccountStatus.TOP_UP_REQUIRED;
		}
	}

	public void activate() {
		if (status != WorkerWarrantyAccountStatus.RELEASED) {
			status = WorkerWarrantyAccountStatus.ACTIVE;
		}
	}

	public void requestRelease() {
		if (status == WorkerWarrantyAccountStatus.TOP_UP_REQUIRED) {
			throw new IllegalStateException("存在待补质保金，不能申请释放");
		}
		if (status == WorkerWarrantyAccountStatus.RELEASED) {
			throw new IllegalStateException("质保金账户已释放");
		}
		status = WorkerWarrantyAccountStatus.RELEASE_PENDING;
	}

	public UUID getWorkerUserId() { return workerUserId; }
	public BigDecimal getEffectiveBalance() { return effectiveBalance; }
	public BigDecimal getDeductedTotal() { return deductedTotal; }
	public BigDecimal getReleasedTotal() { return releasedTotal; }
	public BigDecimal getCapAmount() { return capAmount; }
	public WorkerWarrantyAccountStatus getStatus() { return status; }

	private static BigDecimal positive(BigDecimal value) {
		BigDecimal result = money(Objects.requireNonNull(value));
		if (result.compareTo(BigDecimal.ZERO) <= 0) {
			throw new IllegalArgumentException("金额必须大于0");
		}
		return result;
	}

	static BigDecimal money(BigDecimal value) {
		return value.setScale(2, RoundingMode.HALF_UP);
	}
}
