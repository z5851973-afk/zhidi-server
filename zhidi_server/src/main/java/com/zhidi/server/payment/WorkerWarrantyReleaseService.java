package com.zhidi.server.payment;

import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import java.math.BigDecimal;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class WorkerWarrantyReleaseService {

	private static final Set<BookingStatus> TERMINAL = Set.of(
		BookingStatus.REJECTED, BookingStatus.CANCELLED,
		BookingStatus.NOT_SELECTED, BookingStatus.COMPLETED);
	private final WorkerWarrantyAccountRepository accounts;
	private final WorkerWarrantyLedgerEntryRepository ledger;
	private final BookingRepository bookings;
	private final AfterSaleRepository afterSales;

	public WorkerWarrantyReleaseService(WorkerWarrantyAccountRepository accounts,
			WorkerWarrantyLedgerEntryRepository ledger,
			BookingRepository bookings, AfterSaleRepository afterSales) {
		this.accounts = accounts;
		this.ledger = ledger;
		this.bookings = bookings;
		this.afterSales = afterSales;
	}

	@Transactional
	public WorkerWarrantyAccountResponse release(UUID adminUserId, UUID accountId) {
		WorkerWarrantyAccount account = accounts.findByIdForUpdate(accountId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WARRANTY_ACCOUNT_NOT_FOUND", "质保金账户不存在"));
		if (account.getStatus() != WorkerWarrantyAccountStatus.RELEASE_PENDING) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"WARRANTY_RELEASE_NOT_REQUESTED", "工人尚未申请停止接单并释放质保金");
		}
		boolean hasActiveBooking = bookings
			.findByWorkerUserIdOrderByCreatedAtDesc(account.getWorkerUserId())
			.stream().anyMatch(booking -> !TERMINAL.contains(booking.getStatus()));
		if (hasActiveBooking) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"ACTIVE_BOOKING_EXISTS", "仍有进行中订单，不能释放质保金");
		}
		boolean hasOpenAfterSale = afterSales.findAll().stream()
			.filter(afterSale -> afterSale.getStatus() != AfterSaleStatus.CLOSED)
			.anyMatch(afterSale -> bookings.findById(afterSale.getBookingId())
				.map(booking -> account.getWorkerUserId()
					.equals(booking.getWorkerUserId())).orElse(false));
		if (hasOpenAfterSale) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"OPEN_AFTER_SALE_EXISTS", "仍有未关闭售后，不能释放质保金");
		}
		BigDecimal amount = account.releaseAll();
		accounts.saveAndFlush(account);
		if (amount.compareTo(BigDecimal.ZERO) > 0) {
			ledger.saveAndFlush(
				WorkerWarrantyLedgerEntry.release(account, amount, adminUserId));
		}
		return WorkerWarrantyAccountResponse.from(
			account, BigDecimal.ZERO.setScale(2));
	}
}
