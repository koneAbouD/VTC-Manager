package com.tmk.vtcmanager.interfaces.rest.admin.dto;

public record UpdateUserRequestDto(
        String username,
        String email,
        String firstName,
        String lastName
) {}