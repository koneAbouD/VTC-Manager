package com.tmk.vtcmanager.interfaces.rest.versement.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Un billet remis au guichet : ce qu'il impute à la recette, à la cotisation
 * du même jour, ou aux deux. Une part absente vaut « rien pour cette créance ».
 */
public record VersementRequest(
        @Valid PartRequest recette,
        @Valid PartRequest cotisation,
        @NotNull ModePaiement modeEncaissement,
        @NotNull LocalDate dateEncaissement,
        String reference,
        String commentaire
) {
    public record PartRequest(
            @NotNull Long ligneId,
            @NotNull @Positive BigDecimal montant
    ) {}
}
