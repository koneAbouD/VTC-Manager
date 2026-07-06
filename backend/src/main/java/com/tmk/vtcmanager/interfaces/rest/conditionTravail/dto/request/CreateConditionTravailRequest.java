package com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record CreateConditionTravailRequest(

        @NotBlank
        String nom,

        @Min(1) @Max(2)
        int nbChauffeurs,

        @NotBlank
        String typeProgramme,

        @NotBlank
        String heureDebutService,

        @NotBlank
        String heureFinService,

        // Obligatoire si nbChauffeurs == 2
        String modeAlternance,

        // Obligatoire si nbChauffeurs == 2 && modeAlternance == AUTOMATIQUE
        Integer joursAlternance,

        LocalDate dateDebutAlternance,

        // Null si jourSalaire désactivé côté mobile
        String jourSalaire,

        @NotNull
        BigDecimal objectifRecette,

        @NotBlank
        @Pattern(regexp = "MONTANT_FIXE|MONTANT_REEL",
                message = "typeRecette doit être MONTANT_FIXE ou MONTANT_REEL")
        String typeRecette,

        // Null si typeRecette == MONTANT_REEL
        BigDecimal montantJourSalaire,

        // Prise en compte des jours fériés (suspend recette/cotisation ces jours-là)
        boolean feriesConsideres,

        // Recette due le jour férié (recette fixe) ; null/0 = aucune recette due
        BigDecimal montantJourFerie,

        @NotBlank
        String modeEncaissement,

        @NotBlank
        @Pattern(regexp = "JOURNALIER|HEBDOMADAIRE",
                message = "frequenceVersement doit être JOURNALIER ou HEBDOMADAIRE")
        String frequenceVersement,

        // Null si frequenceVersement != HEBDOMADAIRE
        String jourVersement,

        @NotBlank
        String heureVersement,

        // Vide ou null = tous les jours. Valeurs : LUNDI, MARDI, MERCREDI, JEUDI, VENDREDI, SAMEDI, DIMANCHE
        List<String> joursTravail,

        @Valid
        List<CotisationTemplateRequest> cotisations,

        @Valid
        List<PenaliteTemplateRequest> penalites

) {}
