package com.tmk.vtcmanager.interfaces.rest.penalite.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.math.BigDecimal;
import java.time.LocalDate;

public record LignePenaliteRequest(
        @NotNull Long vehiculeId,
        @NotNull Long chauffeurId,
        Long penaliteTemplateId,
        @NotBlank @Pattern(regexp = "RECETTE_NON_VERSEE|HEURE_FIN_SERVICE_PASSE|EXCES_VITESSE")
        String typePenalite,
        @NotBlank @Pattern(regexp = "BUZZER|AMENDE|AVERTISSEMENT|IMMOBILISATION")
        String typeSanction,
        BigDecimal montant,
        Integer dureeSanctionSecondes,
        Integer dureeImmobilisationMinutes,
        LocalDate dateFaute,
        String commentaire
) {}
