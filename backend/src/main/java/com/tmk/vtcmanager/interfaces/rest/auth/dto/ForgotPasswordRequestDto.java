package com.tmk.vtcmanager.interfaces.rest.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record ForgotPasswordRequestDto(
        @NotBlank(message = "L'email est requis") @Email(message = "Email invalide") String email
) {}