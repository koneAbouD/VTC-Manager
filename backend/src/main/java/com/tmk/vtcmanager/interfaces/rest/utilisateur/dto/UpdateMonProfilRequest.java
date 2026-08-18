package com.tmk.vtcmanager.interfaces.rest.utilisateur.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Champs qu'un utilisateur peut modifier sur sa propre fiche.
 *
 * L'identifiant de connexion ({@code username}) en est volontairement absent :
 * il sert de clé au code d'accès du téléphone et aux comptes déjà provisionnés,
 * le changer à la volée casserait la reprise de session.
 */
public record UpdateMonProfilRequest(
        @NotBlank(message = "Le prénom est obligatoire") @Size(max = 60) String firstName,
        @NotBlank(message = "Le nom est obligatoire") @Size(max = 60) String lastName,
        @NotBlank(message = "L'adresse e-mail est obligatoire") @Email(message = "Adresse e-mail invalide")
        @Size(max = 120) String email,
        // Vide = numéro retiré ; renseigné, il doit rester composable.
        @Pattern(regexp = "^$|^\\+?[0-9\\s\\-]{6,20}$", message = "Numéro de téléphone invalide") String phone
) {}
