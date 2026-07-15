package com.tmk.vtcmanager.interfaces.rest.arrete.dto.request;

import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;

/**
 * Lancement d'un arrêté de compte sur une période libre. Le versement du net se
 * résout par bénéficiaire chauffeur (même quand le périmètre est un véhicule).
 *
 * <p>{@code cotisationIds} et {@code creances} portent la sélection d'un arrêté
 * <b>partiel</b> : {@code null} = toutes les lignes (arrêté total) ; sinon seules
 * les cotisations listées sont restituées et seules les créances listées sont
 * compensées (liste de créances vide = aucune compensation).</p>
 */
public record ArreterCompteRequest(
        @NotNull PerimetreArrete perimetre,
        @NotNull Long perimetreId,
        @NotNull LocalDate periodeDebut,
        @NotNull LocalDate periodeFin,
        LocalDate dateArrete,
        ModePaiement modePaiement,
        Long compteTresorerieId,
        List<Long> cotisationIds,
        List<CreanceRef> creances
) {
    /** Référence d'une créance à compenser : type de document + id du document. */
    public record CreanceRef(TypeDocumentCreance document, Long documentId) {}
}
