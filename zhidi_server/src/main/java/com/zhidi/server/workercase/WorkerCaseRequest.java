package com.zhidi.server.workercase;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.util.List;

public record WorkerCaseRequest(
	@NotBlank @Size(max = 120) String title,
	@NotBlank @Size(max = 1000) String description,
	@NotBlank @Size(max = 80) String serviceCity,
	@Min(2000) @Max(2100) int completionYear,
	@NotEmpty @Size(max = 6) List<@NotBlank @Size(max = 500) String> imageUrls
) {
}
