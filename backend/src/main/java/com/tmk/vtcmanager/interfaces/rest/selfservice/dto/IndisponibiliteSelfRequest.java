package com.tmk.vtcmanager.interfaces.rest.selfservice.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

/**
 * Déclaration d'indisponibilité par le chauffeur connecté (le titulaire = lui-même,
 * dérivé du token). Un chauffeur remplaçant reste obligatoire (le véhicule doit
 * être couvert sur la période).
 */
public record IndisponibiliteSelfRequest(
        @NotNull(message = "Le chauffeur remplaçant est requis") Long chauffeurRemplacantId,
        @NotNull(message = "La date de début est requise") LocalDate dateDebut,
        LocalDate dateFin,
        String motif,
        String commentaire
) {}
