package com.zhidi.server.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
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
import com.zhidi.server.payment.AfterSaleResponse;
import com.zhidi.server.payment.AfterSale;
import com.zhidi.server.payment.AfterSaleRepository;
import com.zhidi.server.payment.AfterSaleService;
import com.zhidi.server.payment.AfterSaleStatus;
import com.zhidi.server.payment.AfterSaleType;
import com.zhidi.server.payment.PaymentOrder;
import com.zhidi.server.payment.PaymentOrderRepository;
import com.zhidi.server.payment.WarrantyRetentionResponse;
import com.zhidi.server.payment.WarrantyRetention;
import com.zhidi.server.payment.WarrantyRetentionRepository;
import com.zhidi.server.payment.WarrantyRetentionService;
import com.zhidi.server.payment.WarrantyRetentionStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.domain.PageImpl;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class AdminControllerTest {

	@Test
	void statusInterventionWritesActorAndTargetToAuditLog() {
		UserRepository users = mock(UserRepository.class);
		BookingRepository bookings = mock(BookingRepository.class);
		OperationLogRepository logs = mock(OperationLogRepository.class);
		AdminController controller = new AdminController(users, bookings, logs,
			mock(AfterSaleService.class), mock(WarrantyRetentionService.class),
			mock(AfterSaleRepository.class), mock(WarrantyRetentionRepository.class),
			mock(PaymentOrderRepository.class));
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

	@Test
	void afterSaleProcessingWritesAuditLogWithDeductionAmount() {
		UserRepository users = mock(UserRepository.class);
		BookingRepository bookings = mock(BookingRepository.class);
		OperationLogRepository logs = mock(OperationLogRepository.class);
		AfterSaleService afterSales = mock(AfterSaleService.class);
		AdminController controller = new AdminController(users, bookings, logs,
			afterSales, mock(WarrantyRetentionService.class),
			mock(AfterSaleRepository.class), mock(WarrantyRetentionRepository.class),
			mock(PaymentOrderRepository.class));
		UUID adminId = UUID.randomUUID();
		UUID afterSaleId = UUID.randomUUID();
		when(afterSales.process(afterSaleId, "返修扣减", new BigDecimal("30.00")))
			.thenReturn(new AfterSaleResponse(afterSaleId, UUID.randomUUID(),
				UUID.randomUUID(), AfterSaleType.COMPLAINT, "水管返潮", null,
				AfterSaleStatus.RESOLVED, "返修扣减", UUID.randomUUID(),
				new BigDecimal("30.00"), Instant.now(), Instant.now()));

		controller.processAfterSale(
			new CurrentUserPrincipal(adminId, "13800138000", Set.of(UserRole.ADMIN)),
			afterSaleId,
			new AdminController.ProcessAfterSaleRequest(
				"返修扣减", new BigDecimal("30.00")));

		ArgumentCaptor<OperationLog> captor = ArgumentCaptor.forClass(OperationLog.class);
		verify(logs).save(captor.capture());
		assertThat(captor.getValue().getActorUserId()).isEqualTo(adminId);
		assertThat(captor.getValue().getAction()).isEqualTo("ADMIN_AFTER_SALE_PROCESS");
		assertThat(captor.getValue().getTargetId()).isEqualTo(afterSaleId.toString());
		assertThat(captor.getValue().getDetailJson()).contains("30.00");
	}

	@Test
	void adminCanListAfterSalesAndWarrantyRetentions() {
		UserRepository users = mock(UserRepository.class);
		BookingRepository bookings = mock(BookingRepository.class);
		OperationLogRepository logs = mock(OperationLogRepository.class);
		AfterSaleService afterSales = mock(AfterSaleService.class);
		WarrantyRetentionService retentions = mock(WarrantyRetentionService.class);
		AdminController controller = new AdminController(users, bookings, logs,
			afterSales, retentions, mock(AfterSaleRepository.class),
			mock(WarrantyRetentionRepository.class), mock(PaymentOrderRepository.class));
		when(afterSales.listForAdmin(any(), org.mockito.Mockito.eq(AfterSaleStatus.OPEN)))
			.thenReturn(new PageImpl<>(List.of(new AfterSaleResponse(
				UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
				AfterSaleType.COMPLAINT, "水管返潮", null, AfterSaleStatus.OPEN,
				null, null, null, Instant.now(), Instant.now()))));
		when(retentions.listForAdmin(any(),
				org.mockito.Mockito.eq(WarrantyRetentionStatus.HELD)))
			.thenReturn(new PageImpl<>(List.of(new WarrantyRetentionResponse(
				UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
				UUID.randomUUID(), UUID.randomUUID(), new BigDecimal("100.00"),
				BigDecimal.ZERO, BigDecimal.ZERO, new BigDecimal("100.00"),
				WarrantyRetentionStatus.HELD, null, null, Instant.now(),
				Instant.now()))));

		assertThat(controller.listAfterSales(0, 20, "OPEN").getBody()
			.data().getContent()).hasSize(1);
		assertThat(controller.listWarrantyRetentions(0, 20, "HELD").getBody()
			.data().getContent()).hasSize(1);
	}

	@Test
	void dashboardIncludesOperationalBacklogAndMoneyMetrics() {
		UserRepository users = mock(UserRepository.class);
		BookingRepository bookings = mock(BookingRepository.class);
		AfterSaleRepository afterSaleRepository = mock(AfterSaleRepository.class);
		WarrantyRetentionRepository retentionRepository =
			mock(WarrantyRetentionRepository.class);
		PaymentOrderRepository paymentRepository = mock(PaymentOrderRepository.class);
		AdminController controller = new AdminController(users, bookings,
			mock(OperationLogRepository.class), mock(AfterSaleService.class),
			mock(WarrantyRetentionService.class), afterSaleRepository,
			retentionRepository, paymentRepository);
		Booking activeBooking = mock(Booking.class);
		when(activeBooking.getStatus()).thenReturn(com.zhidi.server.booking.BookingStatus.HIRED);
		when(bookings.findAll()).thenReturn(List.of(activeBooking));
		when(users.count()).thenReturn(8L);
		when(users.countByCreatedAtAfter(any())).thenReturn(2L);
		AfterSale openAfterSale = mock(AfterSale.class);
		when(openAfterSale.getStatus()).thenReturn(AfterSaleStatus.OPEN);
		when(afterSaleRepository.findAll()).thenReturn(List.of(openAfterSale));
		WarrantyRetention heldRetention = mock(WarrantyRetention.class);
		when(heldRetention.getStatus()).thenReturn(WarrantyRetentionStatus.HELD);
		when(heldRetention.remainingAmount()).thenReturn(new BigDecimal("31.00"));
		when(retentionRepository.findAll()).thenReturn(List.of(heldRetention));
		PaymentOrder pendingReceipt = mock(PaymentOrder.class);
		when(pendingReceipt.getStatus())
			.thenReturn(com.zhidi.server.payment.PaymentOrderStatus.OWNER_REPORTED_PAID);
		PaymentOrder paidToday = mock(PaymentOrder.class);
		when(paidToday.getStatus())
			.thenReturn(com.zhidi.server.payment.PaymentOrderStatus.PAID);
		when(paidToday.getPaidAt()).thenReturn(Instant.now());
		when(paidToday.getAmount()).thenReturn(new BigDecimal("260.00"));
		when(paymentRepository.findAll()).thenReturn(List.of(pendingReceipt, paidToday));

		DashboardResponse dashboard = controller.dashboard().getBody().data();

		assertThat(dashboard.totalUsers()).isEqualTo(8);
		assertThat(dashboard.newUsersToday()).isEqualTo(2);
		assertThat(dashboard.activeBookings()).isEqualTo(1);
		assertThat(dashboard.openAfterSales()).isEqualTo(1);
		assertThat(dashboard.pendingWorkerReceipts()).isEqualTo(1);
		assertThat(dashboard.heldWarrantyAmount()).isEqualByComparingTo("31.00");
		assertThat(dashboard.paidAmountToday()).isEqualByComparingTo("260.00");
	}
}
