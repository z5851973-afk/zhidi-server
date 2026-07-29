package com.zhidi.server.common.error;

import com.zhidi.server.common.api.ApiResponse;
import com.zhidi.server.common.api.TraceIdFilter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class GlobalExceptionHandler {
	private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

	@ExceptionHandler(BusinessException.class)
	ResponseEntity<ApiResponse<Void>> handleBusinessException(BusinessException exception) {
		return ResponseEntity
			.status(exception.status())
			.body(ApiResponse.error(exception.code(), exception.getMessage(), traceId()));
	}

	@ExceptionHandler(MethodArgumentNotValidException.class)
	ResponseEntity<ApiResponse<Void>> handleValidationException() {
		return ResponseEntity
			.badRequest()
			.body(ApiResponse.error("VALIDATION_ERROR", "request validation failed", traceId()));
	}

	@ExceptionHandler(HttpMessageNotReadableException.class)
	ResponseEntity<ApiResponse<Void>> handleUnreadableMessage() {
		return ResponseEntity
			.badRequest()
			.body(ApiResponse.error("INVALID_REQUEST", "request body is invalid", traceId()));
	}

	@ExceptionHandler(MaxUploadSizeExceededException.class)
	ResponseEntity<ApiResponse<Void>> handleUploadTooLarge() {
		return ResponseEntity
			.status(HttpStatus.PAYLOAD_TOO_LARGE)
			.body(ApiResponse.error("IMAGE_TOO_LARGE", "image file exceeds 10MB", traceId()));
	}

	@ExceptionHandler(NoResourceFoundException.class)
	ResponseEntity<ApiResponse<Void>> handleNoResourceFound() {
		return ResponseEntity
			.status(HttpStatus.NOT_FOUND)
			.body(ApiResponse.error("NOT_FOUND", "resource not found", traceId()));
	}

	@ExceptionHandler(Exception.class)
	ResponseEntity<ApiResponse<Void>> handleUnhandledException(Exception exception) {
		String traceId = traceId();
		log.error("Unhandled request exception, traceId={}", traceId, exception);
		return ResponseEntity
			.status(HttpStatus.INTERNAL_SERVER_ERROR)
			.body(ApiResponse.error("INTERNAL_ERROR", "internal server error", traceId));
	}

	private String traceId() {
		return MDC.get(TraceIdFilter.MDC_KEY);
	}
}
