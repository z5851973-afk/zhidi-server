package com.zhidi.server.owner;

import com.zhidi.server.common.error.BusinessException;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OwnerAddressService {

	private final OwnerAddressRepository repository;

	public OwnerAddressService(OwnerAddressRepository repository) {
		this.repository = repository;
	}

	@Transactional(readOnly = true)
	public List<OwnerAddressResponse> list(UUID ownerUserId) {
		return ownedAddresses(ownerUserId).stream().map(OwnerAddressResponse::from).toList();
	}

	@Transactional
	public OwnerAddressResponse create(UUID ownerUserId, OwnerAddressRequest request) {
		List<OwnerAddress> existing = ownedAddresses(ownerUserId);
		boolean makeDefault = request.isDefault() || existing.isEmpty();
		if (makeDefault) {
			existing.forEach(address -> address.markDefault(false));
		}
		OwnerAddress saved = repository.save(
			OwnerAddress.create(ownerUserId, request, makeDefault));
		return OwnerAddressResponse.from(saved);
	}

	@Transactional
	public OwnerAddressResponse update(UUID ownerUserId, UUID addressId,
			OwnerAddressRequest request) {
		OwnerAddress address = findOwned(ownerUserId, addressId);
		address.updateDetails(request);
		if (request.isDefault() && !address.isDefaultAddress()) {
			ownedAddresses(ownerUserId).forEach(item -> item.markDefault(false));
			address.markDefault(true);
		}
		return OwnerAddressResponse.from(address);
	}

	@Transactional
	public OwnerAddressResponse setDefault(UUID ownerUserId, UUID addressId) {
		OwnerAddress address = findOwned(ownerUserId, addressId);
		ownedAddresses(ownerUserId).forEach(item -> item.markDefault(false));
		address.markDefault(true);
		return OwnerAddressResponse.from(address);
	}

	@Transactional
	public void delete(UUID ownerUserId, UUID addressId) {
		OwnerAddress address = findOwned(ownerUserId, addressId);
		boolean wasDefault = address.isDefaultAddress();
		repository.delete(address);
		if (wasDefault) {
			repository.findFirstByOwnerUserIdAndIdNotOrderByUpdatedAtDesc(ownerUserId, addressId)
				.ifPresent(remaining -> remaining.markDefault(true));
		}
	}

	private List<OwnerAddress> ownedAddresses(UUID ownerUserId) {
		return repository.findByOwnerUserIdOrderByDefaultAddressDescUpdatedAtDesc(ownerUserId);
	}

	private OwnerAddress findOwned(UUID ownerUserId, UUID addressId) {
		return repository.findByIdAndOwnerUserId(addressId, ownerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"OWNER_ADDRESS_NOT_FOUND", "地址不存在或无权访问"));
	}
}
