package com.tmk.vtcmanager.interfaces.rest.recu.dto;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.recu.LigneRecuPaiement;
import com.tmk.vtcmanager.application.domain.recu.RecuPaiement;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Le reçu d'écritures d'un même chauffeur, tel que le PDF le rend : de quoi le
 * proposer à l'envoi et en rédiger le message WhatsApp.
 */
public record RecuResponse(
        String chauffeurNom,
        String chauffeurTelephone,
        List<String> vehicules,
        List<ModePaiement> modesPaiement,
        List<Ligne> lignes,
        BigDecimal total,
        BigDecimal resteDu
) {

    public record Ligne(
            String libelle,
            String nature,
            LocalDate journee,
            LocalDate payeLe,
            BigDecimal montant,
            String referenceEcriture,
            String referencePaiement
    ) {}

    public static RecuResponse depuis(RecuPaiement recu) {
        return new RecuResponse(
                recu.chauffeurNom(),
                recu.chauffeurTelephone(),
                recu.vehicules(),
                recu.modesPaiement(),
                recu.lignes().stream().map(RecuResponse::ligne).toList(),
                recu.total(),
                recu.resteDu());
    }

    private static Ligne ligne(LigneRecuPaiement l) {
        return new Ligne(l.libelle(), l.nature() == null ? null : l.nature().name(),
                l.journee(), l.payeLe(), l.montant(), l.referenceEcriture(), l.referencePaiement());
    }
}
