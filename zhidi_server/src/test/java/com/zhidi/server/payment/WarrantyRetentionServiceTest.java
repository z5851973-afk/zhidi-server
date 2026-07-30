package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhidi.server.common.error.BusinessException;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

class WarrantyRetentionServiceTest {

	private final WarrantyRetentionRepository warrantyRetentions =
		mock(WarrantyRetentionRepository.class);
	private WarrantyRetentionService service;

	@BeforeEach
	void setUp() {
		service = new WarrantyRetentionService(warrantyRetentions);
	}

	@Test
	void deductionReducesOnlyTheFrozenWarrantyBalance() {
		UUID retentionId = UUID.randomUUID();
		WarrantyRetention retention = WarrantyRetention.create(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("100.00"));
		ReflectionTestUtils.setField(retention, "id", retentionId);
		when(warrantyRetentions.findById(retentionId))
			.thenReturn(Optional.of(retention));
		when(warrantyRetentions.saveAndFlush(retention)).thenReturn(retention);

		WarrantyRetentionResponse deducted = service.deduct(
			retentionId, new BigDecimal("30.00"), "售后维修扣减");

		assertThat(deducted.status()).isEqualTo(WarrantyRetentionStatus.HELD);
		assertThat(deducted.deductedAmount()).isEqualByComparingTo("30.00");
		assertThat(deducted.remainingAmount()).isEqualByComparingTo("70.00");
	}

	@Test
	void releaseOnlyPaysTheRemainingWarrantyBalanceAfterDeduction() {
		UUID retentionId = UUID.randomUUID();
		WarrantyRetention retention = WarrantyRetention.create(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("100.00"));
		retention.deduct(new BigDecimal("30.00"), "售后维修扣减");
		ReflectionTestUtils.setField(retention, "id", retentionId);
		when(warrantyRetentions.findById(retentionId))
			.thenReturn(Optional.of(retention));
		when(warrantyRetentions.saveAndFlush(retention)).thenReturn(retention);

		WarrantyRetentionResponse released = service.release(retentionId);

		assertThat(released.status()).isEqualTo(WarrantyRetentionStatus.RELEASED);
		assertThat(released.releasedAmount()).isEqualByComparingTo("70.00");
		assertThat(released.remainingAmount()).isEqualByComparingTo("0.00");
	}

	@Test
	void cannotDeductMoreThanRemainingWarrantyBalance() {
		UUID retentionId = UUID.randomUUID();
		WarrantyRetention retention = WarrantyRetention.create(
			UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
			UUID.randomUUID(), new BigDecimal("100.00"));
		when(warrantyRetentions.findById(retentionId))
			.thenReturn(Optional.of(retention));

		assertThatThrownBy(() -> service.deduct(
			retentionId, new BigDecimal("120.00"), "超额扣减"))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("INVALID_DEDUCTION_AMOUNT"));
	}
}
