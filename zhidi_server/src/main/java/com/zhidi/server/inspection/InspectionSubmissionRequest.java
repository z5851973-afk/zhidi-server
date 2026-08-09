package com.zhidi.server.inspection;

import java.util.List;

public record InspectionSubmissionRequest(String note, List<String> photos) {

	public static InspectionSubmissionRequest empty() {
		return new InspectionSubmissionRequest(null, List.of());
	}
}
