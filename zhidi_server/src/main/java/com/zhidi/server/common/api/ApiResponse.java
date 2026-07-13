package com.zhidi.server.common.api;

public record ApiResponse<T>(String code, String message, T data, String traceId) {

	public static <T> ApiResponse<T> ok(T data, String traceId) {
		return new ApiResponse<>("OK", "success", data, traceId);
	}

	public static ApiResponse<Void> error(String code, String message, String traceId) {
		return new ApiResponse<>(code, message, null, traceId);
	}
}
