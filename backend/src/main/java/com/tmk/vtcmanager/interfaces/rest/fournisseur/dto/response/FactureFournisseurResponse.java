package com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.response;

import com.tmk.vtcmanager.application.domain.fournisseur.StatutFactureFournisseur;

import java.math.BigDecimal;
import java.time.LocalDate;

public record FactureFournisseurResponse(
        Long id,
        String reference,
        Long fournisseurId,
        String fournisseurNom,
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
        StatutFactureFournisseur statut,
        /** Échue et non soldée. */
        boolean enRetard,
        String description,
        String motifAnnulation
) {}
