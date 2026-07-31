package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;

public record ElementMaintenanceRequest(
        Long catalogueElementId,
        String libelle,
        /** Exemplaires posés. Absent = un seul, cas de loin le plus fréquent. */
        @Positive Integer quantite,
        /** TOTAL de la ligne : quantité × prix unitaire, pas le prix d'un exemplaire. */
        @NotNull @Positive BigDecimal montant,
        /** Fournisseur de la ligne ; absent = celui de l'intervention. */
        Long partenaireId
) {}
