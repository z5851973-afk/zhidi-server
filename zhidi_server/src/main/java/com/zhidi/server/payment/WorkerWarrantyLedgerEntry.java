package com.zhidi.server.payment;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "worker_warranty_ledger_entries")
public class WorkerWarrantyLedgerEntry extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "account_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID accountId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "worker_user_id", nullable = false, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID workerUserId;

	@Enumerated(EnumType.STRING)
	@Column(name = "entry_type", nullable = false, length = 32)
	private WorkerWarrantyLedgerEntryType entryType;

	@Column(nullable = false, precision = 12, scale = 2)
	private BigDecimal amount;

	@Column(name = "balance_after", nullable = false, precision = 12, scale = 2)
	private BigDecimal balanceAfter;

	@Column(name = "source_type", nullable = false, length = 40)
	private String sourceType;

	@Column(name = "source_id", nullable = false, length = 80)
	private String sourceId;

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "actor_user_id", columnDefinition = "BINARY(16)")
	private UUID actorUserId;

	@Column(length = 300)
	private String detail;

	protected WorkerWarrantyLedgerEntry() {}

	public static WorkerWarrantyLedgerEntry contribution(
			WorkerWarrantyAccount account, WorkerWarrantyContribution contribution,
			UUID adminUserId) {
		WorkerWarrantyLedgerEntry entry = new WorkerWarrantyLedgerEntry();
		entry.accountId = account.getId();
		entry.workerUserId = account.getWorkerUserId();
		entry.entryType = WorkerWarrantyLedgerEntryType.CONTRIBUTION;
		entry.amount = contribution.getAmountDue();
		entry.balanceAfter = account.getEffectiveBalance();
		entry.sourceType = "WARRANTY_CONTRIBUTION";
		entry.sourceId = Objects.toString(contribution.getId(),
			contribution.getSourceReferenceId().toString());
		entry.actorUserId = adminUserId;
		entry.detail = "管理员核验工人质保金补充到账";
		return entry;
	}

	public static WorkerWarrantyLedgerEntry release(
			WorkerWarrantyAccount account, BigDecimal amount, UUID adminUserId) {
		WorkerWarrantyLedgerEntry entry = new WorkerWarrantyLedgerEntry();
		entry.accountId = account.getId();
		entry.workerUserId = account.getWorkerUserId();
		entry.entryType = WorkerWarrantyLedgerEntryType.RELEASE;
		entry.amount = amount;
		entry.balanceAfter = account.getEffectiveBalance();
		entry.sourceType = "ACCOUNT_RELEASE";
		entry.sourceId = account.getId().toString();
		entry.actorUserId = adminUserId;
		entry.detail = "管理员审核释放工人质保金账户余额";
		return entry;
	}

	public static WorkerWarrantyLedgerEntry deduction(
			WorkerWarrantyAccount account, UUID afterSaleId,
			BigDecimal amount, String reason) {
		WorkerWarrantyLedgerEntry entry = new WorkerWarrantyLedgerEntry();
		entry.accountId = account.getId();
		entry.workerUserId = account.getWorkerUserId();
		entry.entryType = WorkerWarrantyLedgerEntryType.DEDUCTION;
		entry.amount = amount;
		entry.balanceAfter = account.getEffectiveBalance();
		entry.sourceType = "AFTER_SALE";
		entry.sourceId = afterSaleId.toString();
		entry.actorUserId = null;
		entry.detail = reason;
		return entry;
	}

	public UUID getAccountId() { return accountId; }
	public UUID getWorkerUserId() { return workerUserId; }
	public WorkerWarrantyLedgerEntryType getEntryType() { return entryType; }
	public BigDecimal getAmount() { return amount; }
	public BigDecimal getBalanceAfter() { return balanceAfter; }
	public String getSourceType() { return sourceType; }
	public String getSourceId() { return sourceId; }
	public UUID getActorUserId() { return actorUserId; }
	public String getDetail() { return detail; }
}
