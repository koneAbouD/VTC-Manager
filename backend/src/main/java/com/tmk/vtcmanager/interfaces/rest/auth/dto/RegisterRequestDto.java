package com.tmk.vtcmanager.interfaces.rest.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

public record RegisterRequestDto(
        @NotBlank(message = "Le nom d'utilisateur est requis") @Size(min = 3, max = 50) String username,
        @NotBlank(message = "L'email est requis") @Email(message = "Email invalide") String email,
        @NotBlank(message = "Le mot de passe est requis") @Size(min = 8, message = "Le mot de passe doit contenir au moins 8 caractères") String password,
        String firstName,
        String lastName,
        List<String> roles
) {}