package com.zhidi.server.quote;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.common.error.BusinessException;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class QuoteService {

	private final QuoteRepository quotes;
	private final BookingRepository bookings;

	public QuoteService(QuoteRepository quotes, BookingRepository bookings) {
		this.quotes = quotes;
		this.bookings = bookings;
	}

	@Transactional
	public QuoteResponse submit(UUID workerUserId, UUID bookingId,
			QuoteRequest request) {
		Booking booking = bookings.findByIdAndWorkerUserId(bookingId, workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "booking is not available"));
		Quote quote = Quote.create(booking.getId(), workerUserId,
			request.items());
		return toResponse(quotes.saveAndFlush(quote));
	}

	@Transactional(readOnly = true)
	public List<QuoteResponse> listForBooking(UUID bookingId) {
		return quotes.findByBookingIdOrderByCreatedAtDesc(bookingId)
			.stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public List<QuoteResponse> listForWorker(UUID workerUserId) {
		return quotes.findByWorkerUserIdOrderByCreatedAtDesc(workerUserId)
			.stream().map(this::toResponse).toList();
	}

	private QuoteResponse toResponse(Quote quote) {
		return new QuoteResponse(quote.getId(), quote.getBookingId(),
			quote.getWorkerUserId(), quote.getItems(), quote.getStatus(),
			quote.getCreatedAt(), quote.getUpdatedAt());
	}
}
