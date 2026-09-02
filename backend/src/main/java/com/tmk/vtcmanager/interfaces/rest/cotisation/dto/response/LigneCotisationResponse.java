package com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response;

import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record LigneCotisationResponse(
        Long id,
        Long vehiculeId,
        String vehiculeImmatriculation,
        Long chauffeurId,
        String chauffeurNom,
        LocalDate dateCotisation,
        String nomCotisation,
        BigDecimal montantDu,
        BigDecimal montantEncaisse,
        BigDecimal montantRestant,
        StatutLigneCotisation statut,
        String motifAnnulation,
        List<EncaissementCotisationResponse> encaissements,
        /**
         * Faux si un arrêté — période comptable close, caisse comptée — interdit
         * désormais de restaurer cet élément annulé. Le client masque alors
         * l'action « Restaurer », qui n'aboutirait pas.
         */
        Boolean restaurable,
        /**
         * Faux si la ligne ne peut plus changer de débiteur : un arrêté de compte
         * l'a consignée, les livres du jour sont fermés, un paiement est en vol,
         * ou elle est annulée. Le client rend alors le chauffeur non modifiable.
         */
        Boolean reaffectable,
        /** Ce qui ferme la réaffectation, en français. Null quand elle est ouverte. */
        String motifNonReaffectable
) {}
