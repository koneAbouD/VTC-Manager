package com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record PenaliteTemplateRequest(

        @NotBlank
        @Pattern(regexp = "RECETTE_NON_VERSEE|HEURE_FIN_SERVICE_PASSE|EXCES_VITESSE",
                message = "typePenalite invalide")
        String typePenalite,

        @NotBlank
        @Pattern(regexp = "BUZZER|AMENDE|AVERTISSEMENT|IMMOBILISATION",
                message = "typeSanction invalide")
        String typeSanction,

        // Présent uniquement si typeSanction == BUZZER
        Integer dureeSanctionSecondes,

        // Présent si typeSanction == AMENDE
        Double montant,

        // Présent uniquement si typeSanction == IMMOBILISATION
        Integer dureeImmobilisationMinutes

) {}
