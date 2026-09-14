package com.tmk.vtcmanager.application.domain.versement;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Une écriture du versement, lue du côté de la créance qu'elle solde.
 *
 * @param libelle   ce qui est nommé au chauffeur : « Recette », ou le nom de
 *                  la cotisation (« Cotisation carburant »)
 * @param annulee   écriture extournée : elle reste au versement — le billet a
 *                  été remis — mais ne compte plus dans son total
 * @param resteDu   ce qu'il reste à devoir sur la créance ; nul pour une
 *                  recette au montant réel, qui n'a pas de dû d'avance
 */
public record ImputationVersement(
        Long operationId,
        String reference,
        NatureImputation nature,
        String libelle,
        Long ligneId,
        LocalDate dateReference,
        BigDecimal montant,
        boolean annulee,
        BigDecimal resteDu
) {}
