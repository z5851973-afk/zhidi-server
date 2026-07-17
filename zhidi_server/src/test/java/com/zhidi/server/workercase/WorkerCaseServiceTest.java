package com.zhidi.server.workercase;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhidi.server.common.error.BusinessException;
import java.time.Year;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class WorkerCaseServiceTest {

	private static final UUID WORKER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000003");
	private static final UUID OTHER_WORKER_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000004");
	private static final UUID CASE_ID =
		UUID.fromString("01904f24-3f5b-7000-8000-000000000103");

	private WorkerCaseRepository repository;
	private WorkerCaseService service;

	@BeforeEach
	void setUp() {
		repository = mock(WorkerCaseRepository.class);
		service = new WorkerCaseService(repository);
		when(repository.save(any(WorkerCase.class)))
			.thenAnswer(invocation -> invocation.getArgument(0));
	}

	@Test
	void createsAndListsCasesForTheAuthenticatedWorker() {
		WorkerCaseRequest request = request("旧房水电改造", Year.now().getValue());

		WorkerCaseResponse created = service.create(WORKER_ID, request);
		when(repository.findByWorkerUserIdOrderByCreatedAtDesc(WORKER_ID))
			.thenReturn(List.of(WorkerCase.create(WORKER_ID, request)));

		assertThat(created.title()).isEqualTo("旧房水电改造");
		assertThat(created.workerUserId()).isEqualTo(WORKER_ID);
		assertThat(created.imageUrls())
			.containsExactly("http://47.109.0.191:8080/uploads/cases/demo.jpg");
		assertThat(service.listMine(WORKER_ID)).hasSize(1);
	}

	@Test
	void updatesAndDeletesOnlyCasesOwnedByTheAuthenticatedWorker() {
		WorkerCase existing = WorkerCase.create(WORKER_ID,
			request("旧标题", Year.now().getValue()));
		when(repository.findByIdAndWorkerUserId(CASE_ID, WORKER_ID))
			.thenReturn(Optional.of(existing));

		WorkerCaseResponse updated = service.update(WORKER_ID, CASE_ID,
			request("新标题", Year.now().getValue()));
		service.delete(WORKER_ID, CASE_ID);

		assertThat(updated.title()).isEqualTo("新标题");
		verify(repository).delete(existing);

		when(repository.findByIdAndWorkerUserId(CASE_ID, OTHER_WORKER_ID))
			.thenReturn(Optional.empty());
		assertThatThrownBy(() -> service.update(OTHER_WORKER_ID, CASE_ID,
			request("越权", Year.now().getValue())))
			.isInstanceOfSatisfying(BusinessException.class,
				error -> assertThat(error.code()).isEqualTo("WORKER_CASE_NOT_FOUND"));
	}

	@Test
	void publicListIsScopedToTheRequestedWorker() {
		when(repository.findByWorkerUserIdOrderByCreatedAtDesc(WORKER_ID))
			.thenReturn(List.of(WorkerCase.create(WORKER_ID,
				request("公开案例", Year.now().getValue()))));

		assertThat(service.listPublic(WORKER_ID))
			.extracting(WorkerCaseResponse::title)
			.containsExactly("公开案例");
		verify(repository).findByWorkerUserIdOrderByCreatedAtDesc(WORKER_ID);
	}

	@Test
	void rejectsFutureYearAndNonPlatformImageUrl() {
		assertThatThrownBy(() -> service.create(WORKER_ID,
			request("未来案例", Year.now().getValue() + 1)))
			.isInstanceOfSatisfying(BusinessException.class,
				error -> assertThat(error.code()).isEqualTo("WORKER_CASE_INVALID_YEAR"));

		WorkerCaseRequest invalidImage = new WorkerCaseRequest(
			"外站图片", "不能使用外站图片", "成都", Year.now().getValue(),
			List.of("https://example.com/not-platform.jpg"));
		assertThatThrownBy(() -> service.create(WORKER_ID, invalidImage))
			.isInstanceOfSatisfying(BusinessException.class,
				error -> assertThat(error.code()).isEqualTo("WORKER_CASE_INVALID_IMAGE"));
	}

	private WorkerCaseRequest request(String title, int year) {
		return new WorkerCaseRequest(title, "完成全屋水电重新布线与验收", "成都", year,
			List.of("http://47.109.0.191:8080/uploads/cases/demo.jpg"));
	}
}
