package com.tmk.vtcmanager.interfaces.rest.auth.dto;

import java.util.List;

public record UserInfoDto(
        String id,
        String username,
        String email,
        String firstName,
        String lastName,
        boolean enabled,
        List<String> roles
) {}