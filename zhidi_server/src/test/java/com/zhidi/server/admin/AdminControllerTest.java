package com.zhidi.server.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.account.UserRepository;
import com.zhidi.server.account.UserRole;
import com.zhidi.server.audit.OperationLog;
import com.zhidi.server.audit.OperationLogRepository;
import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class AdminControllerTest {

	@Test
	void statusInterventionWritesActorAndTargetToAuditLog() {
		UserRepository users = mock(UserRepository.class);
		BookingRepository bookings = mock(BookingRepository.class);
		OperationLogRepository logs = mock(OperationLogRepository.class);
		AdminController controller = new AdminController(users, bookings, logs);
		UUID bookingId = UUID.randomUUID();
		UUID adminId = UUID.randomUUID();
		Booking booking = mock(Booking.class);
		when(bookings.findById(bookingId)).thenReturn(Optional.of(booking));

		controller.updateBookingStatus(
			new CurrentUserPrincipal(adminId, "13800138000", Set.of(UserRole.ADMIN)),
			bookingId, "accepted");

		verify(booking).accept();
		verify(bookings).save(booking);
		ArgumentCaptor<OperationLog> captor = ArgumentCaptor.forClass(OperationLog.class);
		verify(logs).save(captor.capture());
		assertThat(captor.getValue().getActorUserId()).isEqualTo(adminId);
		assertThat(captor.getValue().getAction()).isEqualTo("ADMIN_BOOKING_STATUS_CHANGE");
		assertThat(captor.getValue().getTargetId()).isEqualTo(bookingId.toString());
	}
}
