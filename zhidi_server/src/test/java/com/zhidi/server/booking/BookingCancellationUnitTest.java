package com.zhidi.server.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhidi.server.account.UserRepository;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.payment.WorkerWarrantyAccountService;
import com.zhidi.server.servicerequest.ServiceRequest;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.test.util.ReflectionTestUtils;

class BookingCancellationUnitTest {

	private static final UUID OWNER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000301");
	private static final UUID WORKER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000302");

	@Test
	void ownerCancelAfterOnSiteReturnsBusinessConflictInsteadOfInternalError() {
		BookingRepository bookings = mock(BookingRepository.class);
		BookingService service = new BookingService(bookings,
			mock(ServiceRequestRepository.class), mock(WorkerProfileRepository.class),
			mock(UserRepository.class), mock(OwnerProfileRepository.class),
			mock(VisitProposalRepository.class), mock(SimpMessagingTemplate.class),
			mock(WorkerWarrantyAccountService.class));
		Booking booking = onSiteBooking();
		when(bookings.findByIdAndOwnerUserId(booking.getId(), OWNER_ID))
			.thenReturn(Optional.of(booking));

		Throwable error = catchThrowable(() ->
			service.ownerCancel(OWNER_ID, booking.getId(), "误触取消"));

		assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
			assertThat(ex.status().value()).isEqualTo(409);
			assertThat(ex.code()).isEqualTo("BOOKING_CANNOT_CANCEL");
			assertThat(ex.getMessage()).contains("上门");
		});
	}

	private Booking onSiteBooking() {
		ServiceRequest request = ServiceRequest.create(
			OWNER_ID, "泥瓦", "成都", "测试小区", null);
		ReflectionTestUtils.setField(request, "id",
			UUID.fromString("01904f24-3f5b-7000-8000-000000000303"));
		Booking booking = Booking.createCandidate(request, OWNER_ID,
			"业主", "19900000000", WORKER_ID, "Bill");
		ReflectionTestUtils.setField(booking, "id",
			UUID.fromString("01904f24-3f5b-7000-8000-000000000304"));
		booking.accept();
		booking.proposeVisit();
		booking.scheduleVisit(Instant.parse("2026-08-08T10:00:00Z"));
		booking.confirmArrivalByWorker();
		booking.confirmArrivalByOwner();
		return booking;
	}
}
