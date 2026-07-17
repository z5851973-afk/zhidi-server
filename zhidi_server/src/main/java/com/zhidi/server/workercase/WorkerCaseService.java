package com.zhidi.server.workercase;

import com.zhidi.server.common.error.BusinessException;
import java.net.URI;
import java.time.Year;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class WorkerCaseService {

	private final WorkerCaseRepository repository;

	public WorkerCaseService(WorkerCaseRepository repository) {
		this.repository = repository;
	}

	@Transactional
	public WorkerCaseResponse create(UUID workerUserId, WorkerCaseRequest request) {
		validate(request);
		return WorkerCaseResponse.from(repository.save(WorkerCase.create(workerUserId, request)));
	}

	@Transactional(readOnly = true)
	public List<WorkerCaseResponse> listMine(UUID workerUserId) {
		return listPublic(workerUserId);
	}

	@Transactional(readOnly = true)
	public List<WorkerCaseResponse> listPublic(UUID workerUserId) {
		return repository.findByWorkerUserIdOrderByCreatedAtDesc(workerUserId)
			.stream().map(WorkerCaseResponse::from).toList();
	}

	@Transactional
	public WorkerCaseResponse update(UUID workerUserId, UUID caseId,
			WorkerCaseRequest request) {
		validate(request);
		WorkerCase workerCase = findOwned(workerUserId, caseId);
		workerCase.update(request);
		return WorkerCaseResponse.from(workerCase);
	}

	@Transactional
	public void delete(UUID workerUserId, UUID caseId) {
		repository.delete(findOwned(workerUserId, caseId));
	}

	private WorkerCase findOwned(UUID workerUserId, UUID caseId) {
		return repository.findByIdAndWorkerUserId(caseId, workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"WORKER_CASE_NOT_FOUND", "worker case is not available"));
	}

	private void validate(WorkerCaseRequest request) {
		if (request.completionYear() > Year.now().getValue()) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"WORKER_CASE_INVALID_YEAR", "completion year cannot be in the future");
		}
		if (request.imageUrls() == null || request.imageUrls().isEmpty()
				|| request.imageUrls().size() > 6
				|| request.imageUrls().stream().anyMatch(url -> !isPlatformImage(url))) {
			throw new BusinessException(HttpStatus.BAD_REQUEST,
				"WORKER_CASE_INVALID_IMAGE", "case images must be uploaded by the platform");
		}
	}

	private boolean isPlatformImage(String value) {
		if (value == null || value.isBlank()) {
			return false;
		}
		try {
			URI uri = URI.create(value.trim());
			String path = uri.getPath();
			return path != null && path.startsWith("/uploads/cases/")
				&& !path.substring("/uploads/cases/".length()).contains("/");
		} catch (IllegalArgumentException error) {
			return false;
		}
	}
}
