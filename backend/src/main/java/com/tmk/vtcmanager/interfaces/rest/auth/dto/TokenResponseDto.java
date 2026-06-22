package com.tmk.vtcmanager.interfaces.rest.auth.dto;

public record TokenResponseDto(
        String accessToken,
        String refreshToken,
        Long expiresIn,
        Long refreshExpiresIn,
        String tokenType
) {}