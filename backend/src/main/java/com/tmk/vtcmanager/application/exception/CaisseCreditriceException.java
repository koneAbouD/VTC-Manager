package com.tmk.vtcmanager.application.exception;

import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Décaissement refusé parce qu'il rendrait créditeur un compte sans découvert.
 *
 * <p>Une caisse d'espèces ou un portefeuille mobile money ne peuvent pas
 * présenter un solde négatif : on ne sort pas d'un tiroir — ni d'un compte
 * opérateur — un argent qui n'y est pas. Un solde créditeur signale donc
 * toujours une erreur : recette non saisie, dépense en double, mauvais compte.
 */
public class CaisseCreditriceException extends RuntimeException {

    public CaisseCreditriceException(String libelleCompte, TypeCompteTresorerie type,
                                     BigDecimal solde, BigDecimal montant, LocalDate date) {
        super("Décaissement impossible : « " + libelleCompte + " » ne dispose que de "
                + solde.toPlainString() + " au " + date + ", pour un décaissement de "
                + montant.toPlainString() + ". " + rappel(type)
                + " — vérifiez qu'aucune entrée ne reste à enregistrer.");
    }

    private static String rappel(TypeCompteTresorerie type) {
        return type == TypeCompteTresorerie.MOBILE_MONEY
                ? "Un compte mobile money ne peut pas être à découvert"
                : "Une caisse ne peut pas être à découvert";
    }
}
