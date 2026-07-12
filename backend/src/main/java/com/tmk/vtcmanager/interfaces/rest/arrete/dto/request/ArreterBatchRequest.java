package com.tmk.vtcmanager.interfaces.rest.arrete.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

/** Arrêté en lot : restitution groupée de tous les chauffeurs sur une période. */
public record ArreterBatchRequest(
        @NotNull LocalDate periodeDebut,
        @NotNull LocalDate periodeFin,
        LocalDate dateArrete,
        ModePaiement modePaiement,
        Long compteTresorerieId
) {}
