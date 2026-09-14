package com.tmk.vtcmanager.interfaces.rest.versement.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.List;

/**
 * Plusieurs versements d'un même geste de caisse : un mode, une date et un
 * commentaire pour tout le lot, des parts propres à chaque journée.
 *
 * <p>Même borne que l'encaissement de masse historique : un appui long
 * malheureux ne doit pas lancer des centaines d'écritures.
 */
public record VersementLotRequest(
        @NotEmpty @Size(max = 100) @Valid List<ElementRequest> versements,
        @NotNull ModePaiement modeEncaissement,
        @NotNull LocalDate dateEncaissement,
        String reference,
        String commentaire
) {
    public record ElementRequest(
            @Valid VersementRequest.PartRequest recette,
            @Valid VersementRequest.PartRequest cotisation
    ) {}
}
