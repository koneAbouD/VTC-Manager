package com.tmk.vtcmanager.application.exception;

import java.math.BigDecimal;

/**
 * Comptage refusé faute de motif : le montant compté ne tombe pas sur le solde
 * théorique, et un écart ne s'enregistre pas sans explication.
 *
 * <p>Le message nomme les trois nombres en jeu. Sans eux, l'utilisateur qui
 * croyait tomber juste — parce que son écran affichait un autre solde théorique
 * — lisait une erreur qu'il ne pouvait ni comprendre ni satisfaire : le champ
 * motif ne s'affiche que lorsque l'écran voit lui-même un écart.
 */
public class MotifEcartObligatoireException extends RuntimeException {

    private final transient BigDecimal soldeTheorique;
    private final transient BigDecimal soldeCompte;
    private final transient BigDecimal ecart;

    public MotifEcartObligatoireException(BigDecimal soldeTheorique, BigDecimal soldeCompte,
                                          BigDecimal ecart) {
        super("Le comptage (" + soldeCompte + ") diffère du solde théorique arrêté à cette date ("
                + soldeTheorique + ") de " + ecart + " : précisez le motif de l'écart.");
        this.soldeTheorique = soldeTheorique;
        this.soldeCompte = soldeCompte;
        this.ecart = ecart;
    }

    public BigDecimal getSoldeTheorique() {
        return soldeTheorique;
    }

    public BigDecimal getSoldeCompte() {
        return soldeCompte;
    }

    public BigDecimal getEcart() {
        return ecart;
    }
}
