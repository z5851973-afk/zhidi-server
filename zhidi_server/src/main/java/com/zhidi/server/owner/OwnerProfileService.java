package com.zhidi.server.owner;

import java.util.Objects;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class OwnerProfileService {

	private static final String DEFAULT_CITY = "成都";

	private final OwnerProfileRepository repository;

	public OwnerProfileService(OwnerProfileRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public OwnerProfileResponse get(UUID userId, String phone) {
		Objects.requireNonNull(userId);
		return repository.findByUserId(userId)
			.map(profile -> toResponse(profile, phone))
			.orElseGet(() -> new OwnerProfileResponse(
				userId, phone, null, DEFAULT_CITY, null, null, null, false));
	}

	@Transactional
	public OwnerProfileResponse update(UUID userId, String phone, OwnerProfileRequest request) {
		Objects.requireNonNull(userId);
		Objects.requireNonNull(request);
		String name = normalizeNullable(request.name());
		String requestedCity = normalizeNullable(request.city());
		String city = requestedCity == null ? DEFAULT_CITY : requestedCity;
		String decorationType = normalizeNullable(request.decorationType());
		String address = normalizeNullable(request.address());

		OwnerProfile profile = repository.findByUserId(userId)
			.orElseGet(() -> OwnerProfile.create(
				userId, name, city, decorationType, address, request.area()));
		profile.update(name, city, decorationType, address, request.area());
		return toResponse(repository.save(profile), phone);
	}

	private OwnerProfileResponse toResponse(OwnerProfile profile, String phone) {
		boolean complete = profile.getName() != null
			&& profile.getDecorationType() != null
			&& profile.getAddress() != null
			&& profile.getArea() != null;
		return new OwnerProfileResponse(profile.getUserId(), phone, profile.getName(),
			profile.getCity(), profile.getDecorationType(), profile.getAddress(),
			profile.getArea(), complete);
	}

	private String normalizeNullable(String value) {
		return StringUtils.hasText(value) ? value.trim() : null;
	}
}
