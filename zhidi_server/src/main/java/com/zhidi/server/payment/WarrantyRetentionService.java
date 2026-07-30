package com.zhidi.server.payment;

import com.zhidi.server.common.error.BusinessException;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class WarrantyRetentionService {

	private final WarrantyRetentionRepository warrantyRetentions;

	public WarrantyRetentionService(WarrantyRetentionRepository warrantyRetentions) {
		this.warrantyRetentions = warrantyRetentions;
	}

	@Transactional
	public WarrantyRetentionResponse release(UUID retentionId) {
		WarrantyRetention retention = find(retentionId);
		try {
			retention.releaseRemaining();
		} catch (IllegalStateException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", ex.getMessage());
		}
		return WarrantyRetentionResponse.from(
			warrantyRetentions.saveAndFlush(retention));
	}

	@Transactional
	public WarrantyRetentionResponse deduct(UUID retentionId, BigDecimal amount,
			String reason) {
		WarrantyRetention retention = find(retentionId);
		try {
			retention.deduct(amount, reason);
		} catch (IllegalArgumentException ex) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"INVALID_DEDUCTION_AMOUNT", ex.getMessage());
		} catch (IllegalStateException ex) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", ex.getMessage());
		}
		return WarrantyRetentionResponse.from(
			warrantyRetentions.saveAndFlush(retention));
	}

	@Transactional(readOnly = true)
	public List<WarrantyRetentionResponse> listForUser(UUID userId) {
		List<WarrantyRetention> workerRetentions =
			warrantyRetentions.findByWorkerUserIdOrderByCreatedAtDesc(userId);
		if (!workerRetentions.isEmpty()) {
			return workerRetentions.stream()
				.map(WarrantyRetentionResponse::from).toList();
		}
		return warrantyRetentions.findByOwnerUserIdOrderByCreatedAtDesc(userId)
			.stream().map(WarrantyRetentionResponse::from).toList();
	}

	private WarrantyRetention find(UUID retentionId) {
		return warrantyRetentions.findById(retentionId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WARRANTY_RETENTION_NOT_FOUND", "质保金记录不存在"));
	}
}
