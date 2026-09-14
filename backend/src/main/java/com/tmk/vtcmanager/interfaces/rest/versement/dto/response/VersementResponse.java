package com.tmk.vtcmanager.interfaces.rest.versement.dto.response;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.versement.NatureImputation;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * La pièce de caisse telle que le détail et le reçu la lisent : le billet, et
 * la créance que solde chacune de ses écritures.
 */
public record VersementResponse(
        UUID versementId,
        LocalDate dateEncaissement,
        ModePaiement modePaiement,
        Long chauffeurId,
        String chauffeurNom,
        String chauffeurTelephone,
        Long vehiculeId,
        String vehiculeImmatriculation,
        /** Imputations extournées exclues. */
        BigDecimal total,
        List<ImputationResponse> imputations
) {
    public record ImputationResponse(
            Long operationId,
            String reference,
            NatureImputation nature,
            String libelle,
            Long ligneId,
            LocalDate dateReference,
            BigDecimal montant,
            boolean annulee,
            /** Nul pour une recette au montant réel : aucun dû d'avance. */
            BigDecimal resteDu
    ) {}
}
