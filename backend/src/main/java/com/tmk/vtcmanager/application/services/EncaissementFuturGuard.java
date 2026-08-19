package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.exception.EncaissementFuturException;

import java.time.LocalDate;

/**
 * Verrou de l'encaissement postdaté.
 *
 * <p>Un encaissement n'est pas une prévision : il constate de l'argent déjà
 * compté. Le dater de demain ferait entrer en caisse une somme que personne n'a
 * reçue, et fausserait tous les soldes à date jusqu'à ce que le jour arrive.
 *
 * <p>Le postdatage servait surtout à contourner les deux autres verrous — passer
 * l'écriture « à une date postérieure » quand la caisse du jour était déjà
 * comptée. Le remède était pire : l'extourne d'une opération ainsi postdatée
 * porte la date du jour de l'annulation, donc une date <em>antérieure</em> à
 * l'écriture qu'elle annule. Fermer cette porte oblige à passer par le bon
 * geste — retirer le relevé de caisse et recompter.
 *
 * <p>Complémentaire de {@link PeriodeClotureeGuard} et {@link CaisseClotureeGuard},
 * qui ferment le passé ; celui-ci ferme l'avenir.
 */
public class EncaissementFuturGuard {

    public void verifier(LocalDate dateEncaissement) {
        if (dateEncaissement == null) return;
        LocalDate aujourdHui = LocalDate.now();
        if (dateEncaissement.isAfter(aujourdHui)) {
            throw new EncaissementFuturException(dateEncaissement, aujourdHui);
        }
    }
}
