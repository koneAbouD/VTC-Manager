package com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.request;

import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.chauffeur.Genre;
import com.tmk.vtcmanager.application.domain.chauffeur.TypeChauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.TypePermis;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

import java.time.LocalDate;
import java.util.Set;

public record ChauffeurRequest(
        @NotBlank String nom,
        @NotBlank String prenom,
        Genre genre,
        TypeChauffeur type,
        LocalDate dateNaissance,
        String telephone,
        @Email String email,
        String adresse,
        ChauffeurStatus statut,
        LocalDate dateEmbauche,
        // Données du permis de conduire (obligatoires à la création, optionnels à la mise à jour sans nouveau fichier)
        String numeroPermis,
        Set<TypePermis> typesPermis,
        LocalDate dateEmissionPermis,
        LocalDate dateExpirationPermis,
        Boolean deletePhoto
) {}