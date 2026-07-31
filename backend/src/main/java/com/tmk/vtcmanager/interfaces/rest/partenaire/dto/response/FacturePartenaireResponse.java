package com.tmk.vtcmanager.interfaces.rest.partenaire.dto.response;

import com.tmk.vtcmanager.application.domain.partenaire.StatutFacturePartenaire;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record FacturePartenaireResponse(
        Long id,
        String reference,
        Long partenaireId,
        String partenaireNom,
        String numeroPiece,
        Long categorieId,
        String categorieLibelle,
        Long vehiculeId,
        String vehiculeImmatriculation,
        LocalDate dateFacture,
        LocalDate dateEcheance,
        BigDecimal montant,
        BigDecimal montantPaye,
        /** Ce qui reste à payer. */
        BigDecimal restantDu,
        StatutFacturePartenaire statut,
        /** Échue et non soldée. */
        boolean enRetard,
        String description,
        String motifAnnulation,
        /** Intervention d'origine, quand la dette naît d'une maintenance. */
        Long maintenanceId,
        /** Ce que la dette paie, ligne à ligne. Vide pour une facture saisie. */
        List<LigneDetteResponse> lignes
) {
    /** Un poste couvert par la dette. */
    public record LigneDetteResponse(String libelle, BigDecimal montant) {}
}
