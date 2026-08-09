package com.zhidi.server.servicerequest;

import com.zhidi.server.booking.BookingResponse;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record ServiceRequestResponse(
	UUID id,
	UUID ownerUserId,
	String trade,
	String serviceCity,
	String serviceAddress,
	String remark,
	BigDecimal areaSqm,
	Short bedroomCount,
	Short livingRoomCount,
	Short kitchenCount,
	Short bathroomCount,
	ServiceRequestStatus status,
	List<BookingResponse> candidates,
	Instant createdAt,
	Instant updatedAt,
	long activeCandidateCount,
	long availableCandidateSlots,
	boolean canAddCandidates
) {
	public ServiceRequestResponse(UUID id, UUID ownerUserId, String trade,
			String serviceCity, String serviceAddress, String remark,
			ServiceRequestStatus status, List<BookingResponse> candidates,
			Instant createdAt, Instant updatedAt, long activeCandidateCount,
			long availableCandidateSlots, boolean canAddCandidates) {
		this(id, ownerUserId, trade, serviceCity, serviceAddress, remark,
			null, null, null, null, null, status, candidates, createdAt, updatedAt,
			activeCandidateCount, availableCandidateSlots, canAddCandidates);
	}
}
