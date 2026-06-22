package com.tmk.vtcmanager.application.domain.common;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Structure standard de réponse API")
public record ApiResponse<T>(String code, String message, T data) {

    public static final String SUCCESS_CODE = "00";
    public static final String SUCCESS_MESSAGE = "Opération réussie";
    public static final String FAIL_CODE = "01";

    public ApiResponse(String code, String message) {
        this(code, message, null);
    }

    public ApiResponse(T data) {
        this(SUCCESS_CODE, SUCCESS_MESSAGE, data);
    }

    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(data);
    }

    public static <T> ApiResponse<T> success(String message, T data) {
        return new ApiResponse<>(SUCCESS_CODE, message, data);
    }

    public static <T> ApiResponse<T> fail(String message) {
        return new ApiResponse<>(FAIL_CODE, message, null);
    }
}
