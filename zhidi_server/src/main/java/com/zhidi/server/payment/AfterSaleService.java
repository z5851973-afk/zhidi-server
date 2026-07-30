package com.zhidi.server.payment;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.common.error.BusinessException;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AfterSaleService {

	private final AfterSaleRepository afterSales;
	private final BookingRepository bookings;
	private final WarrantyRetentionRepository warrantyRetentions;

	public AfterSaleService(AfterSaleRepository afterSales,
			BookingRepository bookings,
			WarrantyRetentionRepository warrantyRetentions) {
		this.afterSales = afterSales;
		this.bookings = bookings;
		this.warrantyRetentions = warrantyRetentions;
	}

	@Transactional
	public AfterSaleResponse create(UUID bookingId, UUID ownerUserId,
			AfterSaleType type, String reason, String evidence) {
		Booking booking = bookings.findById(bookingId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));

		if (!booking.getOwnerUserId().equals(ownerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_OWNER", "只有业主才能创建售后申请");
		}

		if (reason == null || reason.isBlank()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"REASON_REQUIRED", "售后原因不能为空");
		}

		AfterSale afterSale = AfterSale.create(bookingId, ownerUserId, type,
			reason.trim(), evidence);

		return AfterSaleResponse.from(afterSales.saveAndFlush(afterSale));
	}

	@Transactional(readOnly = true)
	public AfterSaleResponse getAfterSale(UUID userId, UUID afterSaleId) {
		AfterSale afterSale = afterSales.findById(afterSaleId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"AFTER_SALE_NOT_FOUND", "售后工单不存在"));
		Booking booking = bookings.findById(afterSale.getBookingId())
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"AFTER_SALE_NOT_FOUND", "售后工单不存在"));
		if (!booking.getOwnerUserId().equals(userId)
				&& !booking.getWorkerUserId().equals(userId)) {
			throw new BusinessException(HttpStatus.NOT_FOUND,
				"AFTER_SALE_NOT_FOUND", "售后工单不存在");
		}
		return AfterSaleResponse.from(afterSale);
	}

	@Transactional(readOnly = true)
	public List<AfterSaleResponse> listForUser(UUID userId) {
		return afterSales.findByOwnerUserIdOrderByCreatedAtDesc(userId)
			.stream().map(AfterSaleResponse::from).toList();
	}

	@Transactional
	public AfterSaleResponse process(UUID afterSaleId, String resolution) {
		return process(afterSaleId, resolution, null);
	}

	@Transactional
	public AfterSaleResponse process(UUID afterSaleId, String resolution,
			BigDecimal warrantyDeductionAmount) {
		AfterSale afterSale = afterSales.findById(afterSaleId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"AFTER_SALE_NOT_FOUND", "售后工单不存在"));

		if (afterSale.getStatus() == AfterSaleStatus.CLOSED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"ALREADY_CLOSED", "售后工单已关闭");
		}

		if (resolution == null || resolution.isBlank()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"RESOLUTION_REQUIRED", "处理方案不能为空");
		}

		if (warrantyDeductionAmount != null
				&& warrantyDeductionAmount.compareTo(BigDecimal.ZERO) > 0) {
			WarrantyRetention retention =
				warrantyRetentions.findFirstByBookingIdOrderByCreatedAtDesc(
					afterSale.getBookingId())
					.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
						"WARRANTY_RETENTION_NOT_FOUND", "该售后工单没有可扣减的质保金"));
			try {
				retention.deduct(warrantyDeductionAmount, resolution.trim());
			} catch (IllegalArgumentException ex) {
				throw new BusinessException(HttpStatus.BAD_REQUEST,
					"INVALID_DEDUCTION_AMOUNT", ex.getMessage());
			} catch (IllegalStateException ex) {
				throw new BusinessException(HttpStatus.CONFLICT,
					"INVALID_STATUS", ex.getMessage());
			}
			warrantyRetentions.saveAndFlush(retention);
			afterSale.process(resolution.trim(), retention.getId(),
				warrantyDeductionAmount.setScale(2));
		} else {
			afterSale.process(resolution.trim());
		}
		return AfterSaleResponse.from(afterSales.saveAndFlush(afterSale));
	}
}
