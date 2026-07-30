package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.common.error.BusinessException;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

class AfterSaleServiceTest {

	private final AfterSaleRepository afterSales = mock(AfterSaleRepository.class);
	private final BookingRepository bookings = mock(BookingRepository.class);
	private final WarrantyRetentionRepository warrantyRetentions =
		mock(WarrantyRetentionRepository.class);
	private AfterSaleService service;

	@BeforeEach
	void setUp() {
		service = new AfterSaleService(afterSales, bookings, warrantyRetentions);
	}

	@Test
	void processingAfterSaleCanDeductWarrantyRetentionForTheBooking() {
		UUID afterSaleId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		AfterSale afterSale = AfterSale.create(
			bookingId, UUID.randomUUID(), AfterSaleType.COMPLAINT,
			"水管返潮", null);
		ReflectionTestUtils.setField(afterSale, "id", afterSaleId);
		WarrantyRetention retention = WarrantyRetention.create(
			UUID.randomUUID(), UUID.randomUUID(), bookingId, UUID.randomUUID(),
			new BigDecimal("100.00"));
		ReflectionTestUtils.setField(retention, "id", UUID.randomUUID());
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		when(warrantyRetentions.findFirstByBookingIdOrderByCreatedAtDesc(bookingId))
			.thenReturn(Optional.of(retention));
		when(warrantyRetentions.saveAndFlush(retention)).thenReturn(retention);
		when(afterSales.saveAndFlush(afterSale)).thenReturn(afterSale);

		AfterSaleResponse response = service.process(
			afterSaleId, "平台判定返修，扣减质保金 ¥30",
			new BigDecimal("30.00"));

		assertThat(response.status()).isEqualTo(AfterSaleStatus.RESOLVED);
		assertThat(response.warrantyRetentionId()).isEqualTo(retention.getId());
		assertThat(response.warrantyDeductionAmount())
			.isEqualByComparingTo("30.00");
		assertThat(retention.getDeductedAmount()).isEqualByComparingTo("30.00");
		assertThat(retention.remainingAmount()).isEqualByComparingTo("70.00");
	}

	@Test
	void processingAfterSaleWithDeductionRequiresAWarrantyRetention() {
		UUID afterSaleId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		AfterSale afterSale = AfterSale.create(
			bookingId, UUID.randomUUID(), AfterSaleType.COMPLAINT,
			"水管返潮", null);
		when(afterSales.findById(afterSaleId)).thenReturn(Optional.of(afterSale));
		when(warrantyRetentions.findFirstByBookingIdOrderByCreatedAtDesc(bookingId))
			.thenReturn(Optional.empty());

		assertThatThrownBy(() -> service.process(
			afterSaleId, "平台判定扣减", new BigDecimal("30.00")))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("WARRANTY_RETENTION_NOT_FOUND"));
	}
}
