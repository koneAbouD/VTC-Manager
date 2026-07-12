package com.tmk.vtcmanager.interfaces.rest.arrete.dto.request;

import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

/**
 * Lancement d'un arrêté de compte sur une période libre. Le versement du net se
 * résout par bénéficiaire chauffeur (même quand le périmètre est un véhicule).
 */
public record ArreterCompteRequest(
        @NotNull PerimetreArrete perimetre,
        @NotNull Long perimetreId,
        @NotNull LocalDate periodeDebut,
        @NotNull LocalDate periodeFin,
        LocalDate dateArrete,
        ModePaiement modePaiement,
        Long compteTresorerieId
) {}
