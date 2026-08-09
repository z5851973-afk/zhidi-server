package com.zhidi.server.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.account.UserRole;
import com.zhidi.server.common.security.CurrentUserPrincipal;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.time.Instant;
import org.junit.jupiter.api.Test;

class AfterSaleControllerTest {

	@Test
	void participantCanAppendIdempotentTextAndEvidenceEvent() {
		AfterSaleService service = mock(AfterSaleService.class);
		AfterSaleController controller = new AfterSaleController(service);
		UUID userId = UUID.randomUUID();
		UUID afterSaleId = UUID.randomUUID();
		AfterSaleEventResponse expected = new AfterSaleEventResponse(
			UUID.randomUUID(), afterSaleId, userId, AfterSaleActorRole.OWNER,
			AfterSaleEventType.PARTICIPANT_MESSAGE, "补充照片",
			List.of("/uploads/after-sales/a.jpg"), "mobile-1", Instant.now());
		when(service.appendParticipantEvent(userId, afterSaleId, "补充照片",
			List.of("/uploads/after-sales/a.jpg"), "mobile-1"))
			.thenReturn(expected);

		var response = controller.appendEvent(
			new CurrentUserPrincipal(userId, "13800138000", Set.of(UserRole.OWNER)),
			afterSaleId,
			new AfterSaleController.AppendAfterSaleEventRequest(
				"补充照片", List.of("/uploads/after-sales/a.jpg"), "mobile-1"));

		assertThat(response.data()).isSameAs(expected);
		verify(service).appendParticipantEvent(userId, afterSaleId, "补充照片",
			List.of("/uploads/after-sales/a.jpg"), "mobile-1");
	}

	@Test
	void ownerCanLoadExactBookingContextBeforeCreation() {
		AfterSaleService service = mock(AfterSaleService.class);
		AfterSaleController controller = new AfterSaleController(service);
		UUID ownerId = UUID.randomUUID();
		UUID bookingId = UUID.randomUUID();
		AfterSaleDetailResponse.OrderContext expected =
			new AfterSaleDetailResponse.OrderContext(bookingId, "COMPLETED", "carpentry",
				"张女士", "李师傅", "成都市", "武侯区一号", null, null,
				null, null, "PAID",
				new AfterSaleDetailResponse.InspectionSummary("PASSED", 1, 1));
		when(service.getBookingContext(ownerId, bookingId)).thenReturn(expected);

		var response = controller.getBookingContext(
			new CurrentUserPrincipal(ownerId, "13800138000", Set.of(UserRole.OWNER)),
			bookingId);

		assertThat(response.data()).isSameAs(expected);
		assertThat(response.data().bookingStatus()).isEqualTo("COMPLETED");
		verify(service).getBookingContext(ownerId, bookingId);
	}
}
