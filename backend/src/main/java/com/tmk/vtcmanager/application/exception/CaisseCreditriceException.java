package com.tmk.vtcmanager.application.exception;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Décaissement refusé parce qu'il rendrait une caisse créditrice.
 *
 * <p>Une caisse d'espèces ne peut pas présenter un solde négatif : on ne sort
 * pas d'un tiroir un argent qui n'y est pas. Un solde créditeur signale donc
 * toujours une erreur — recette non saisie, dépense en double, mauvais compte —
 * et non un découvert.
 */
public class CaisseCreditriceException extends RuntimeException {

    public CaisseCreditriceException(String libelleCompte, BigDecimal solde,
                                     BigDecimal montant, LocalDate date) {
        super("Décaissement impossible : « " + libelleCompte + " » ne dispose que de "
                + solde.toPlainString() + " au " + date + ", pour un décaissement de "
                + montant.toPlainString() + ". Une caisse ne peut pas être à découvert —"
                + " vérifiez qu'aucune recette ne reste à enregistrer.");
    }
}
