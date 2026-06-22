package com.tmk.vtcmanager.interfaces.rest.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record RefreshTokenRequestDto(
        @NotBlank(message = "Le refresh token est requis") String refreshToken
) {}