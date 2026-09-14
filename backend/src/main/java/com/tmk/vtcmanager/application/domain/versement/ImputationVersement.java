package com.tmk.vtcmanager.application.domain.versement;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Une écriture d'encaissement, lue du côté de la créance qu'elle solde.
 *
 * @param libelle           ce qui est nommé au chauffeur : « Recette », le nom
 *                          de la cotisation, « Pénalité (recette non versée) »
 * @param annulee           écriture extournée : le billet a été remis, mais
 *                          elle ne compte plus
 * @param resteDu           ce qu'il reste à devoir sur la créance ; nul pour
 *                          une recette au montant réel, qui n'a pas de dû d'avance
 * @param referencePaiement référence saisie au guichet — le numéro de
 *                          transaction Mobile Money — distincte de la
 *                          référence de l'écriture au journal
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
        BigDecimal resteDu,
        String referencePaiement
) {}
