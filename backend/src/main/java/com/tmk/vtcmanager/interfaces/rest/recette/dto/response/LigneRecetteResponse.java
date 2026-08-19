package com.tmk.vtcmanager.interfaces.rest.recette.dto.response;

import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record LigneRecetteResponse(
        Long id,
        Long vehiculeId,
        String vehiculeImmatriculation,
        Long chauffeurId,
        String chauffeurNom,
        LocalDate dateRecette,
        BigDecimal montantAttendu,
        BigDecimal montantEncaisse,
        BigDecimal montantRestant,
        StatutLigneRecette statut,
        String motifAnnulation,
        List<EncaissementResponse> encaissements,
        /**
         * Faux si un arrêté — période comptable close, caisse comptée — interdit
         * désormais de restaurer cet élément annulé. Le client masque alors
         * l'action « Restaurer », qui n'aboutirait pas.
         */
        Boolean restaurable
) {}
