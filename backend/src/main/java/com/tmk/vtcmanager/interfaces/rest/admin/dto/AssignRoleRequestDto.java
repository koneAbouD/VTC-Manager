package com.tmk.vtcmanager.interfaces.rest.admin.dto;

import jakarta.validation.constraints.NotBlank;

public record AssignRoleRequestDto(
        @NotBlank(message = "Le nom du rôle est requis") String roleName
) {}