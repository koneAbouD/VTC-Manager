package com.tmk.vtcmanager.interfaces.rest.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginRequestDto(
        @NotBlank(message = "Le nom d'utilisateur est requis") String username,
        @NotBlank(message = "Le mot de passe est requis") String password
) {}