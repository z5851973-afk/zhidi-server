package com.zhidi.server.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.zhidi.server.account.UserRepository;
import com.zhidi.server.common.error.BusinessException;
import com.zhidi.server.owner.OwnerProfileRepository;
import com.zhidi.server.payment.WorkerWarrantyAccountService;
import com.zhidi.server.servicerequest.ServiceRequestRepository;
import com.zhidi.server.worker.WorkerProfileRepository;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.mockito.InOrder;
import static org.mockito.Mockito.inOrder;

class BookingWarrantyEligibilityTest {

	@Test
	void workerWithOutstandingWarrantyContributionCannotAcceptNewBooking() {
		BookingRepository bookings = mock(BookingRepository.class);
		WorkerWarrantyAccountService warrantyAccounts =
			mock(WorkerWarrantyAccountService.class);
		UUID workerId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		when(warrantyAccounts.canAcceptNewJobsForUpdate(workerId)).thenReturn(false);
		BookingService service = new BookingService(bookings,
			mock(ServiceRequestRepository.class), mock(WorkerProfileRepository.class),
			mock(UserRepository.class), mock(OwnerProfileRepository.class),
			mock(VisitProposalRepository.class), mock(SimpMessagingTemplate.class),
			warrantyAccounts);

		assertThatThrownBy(() -> service.accept(workerId, bookingId))
			.isInstanceOfSatisfying(BusinessException.class, ex -> {
				assertThat(ex.status().value()).isEqualTo(409);
				assertThat(ex.code())
					.isEqualTo("WORKER_WARRANTY_TOP_UP_REQUIRED");
			});
		verifyNoInteractions(bookings);
	}

	@Test
	void eligibleWorkerLocksBookingAfterAccountGateThenChecksOwnership() {
		BookingRepository bookings = mock(BookingRepository.class);
		WorkerWarrantyAccountService warrantyAccounts =
			mock(WorkerWarrantyAccountService.class);
		UUID workerId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		Booking foreignBooking = mock(Booking.class);
		when(warrantyAccounts.canAcceptNewJobsForUpdate(workerId)).thenReturn(true);
		when(bookings.findByIdForUpdate(bookingId))
			.thenReturn(Optional.of(foreignBooking));
		when(foreignBooking.getWorkerUserId()).thenReturn(UUID.randomUUID());
		BookingService service = new BookingService(bookings,
			mock(ServiceRequestRepository.class), mock(WorkerProfileRepository.class),
			mock(UserRepository.class), mock(OwnerProfileRepository.class),
			mock(VisitProposalRepository.class), mock(SimpMessagingTemplate.class),
			warrantyAccounts);

		assertThatThrownBy(() -> service.accept(workerId, bookingId))
			.isInstanceOfSatisfying(BusinessException.class, ex ->
				assertThat(ex.code()).isEqualTo("BOOKING_NOT_FOUND"));

		InOrder lockOrder = inOrder(warrantyAccounts, bookings);
		lockOrder.verify(warrantyAccounts).canAcceptNewJobsForUpdate(workerId);
		lockOrder.verify(bookings).findByIdForUpdate(bookingId);
	}
}
