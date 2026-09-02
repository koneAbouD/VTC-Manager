package com.tmk.vtcmanager.interfaces.rest.recette.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Un versement qui solde plusieurs journées d'un coup : un mode, une date et un
 * commentaire pour tout le lot, un montant propre à chaque ligne.
 *
 * <p>La borne haute existe pour que le guichet ne lance pas, d'un appui long
 * malheureux, un lot de plusieurs centaines d'écritures.
 */
public record EncaissementLotRequest(
        @NotEmpty @Size(max = 100) @Valid List<LigneMontantRequest> lignes,
        @NotNull ModePaiement modeEncaissement,
        @NotNull LocalDate dateEncaissement,
        String reference,
        String commentaire
) {
    public record LigneMontantRequest(
            @NotNull Long ligneId,
            @NotNull @Positive BigDecimal montant
    ) {}
}
