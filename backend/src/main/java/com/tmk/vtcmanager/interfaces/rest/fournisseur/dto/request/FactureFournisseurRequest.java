package com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record FactureFournisseurRequest(
        @NotNull Long fournisseurId,
        @Size(max = 100) String numeroPiece,
        Long categorieId,
        Long vehiculeId,
        /** Date de la facture : elle date la charge. Absente = aujourd'hui. */
        LocalDate dateFacture,
        /** Échéance convenue. Absente = due à réception. */
        LocalDate dateEcheance,
        @NotNull @Positive BigDecimal montant,
        String description
) {}
