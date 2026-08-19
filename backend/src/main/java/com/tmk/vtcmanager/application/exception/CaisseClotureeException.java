package com.tmk.vtcmanager.application.exception;

import java.time.LocalDate;

/**
 * Écriture refusée parce que la caisse a déjà été comptée pour cette journée.
 *
 * <p>Le geste à conseiller dépend d'où tombe le comptage. S'il est antérieur à
 * l'écriture, la correction se passe simplement après lui : il suffit de la
 * dater du lendemain de l'arrêté ou plus tard. Mais si le comptage porte sur la
 * journée même de l'écriture, ce conseil devient mauvais — il reviendrait à
 * postdater une recette réellement encaissée aujourd'hui, pour contourner un
 * verrou dont c'est précisément le rôle. Il faut alors rouvrir la journée :
 * retirer le relevé, saisir l'écriture, recompter la caisse.
 *
 * <p>Le message part tel quel au client (409 {@code CAISSE_CLOTUREE}) : il
 * s'adresse à la personne qui encaisse et nomme le bouton qu'elle voit
 * (« Retirer », sur le bandeau du dernier relevé de la fenêtre de comptage).
 */
public class CaisseClotureeException extends RuntimeException {

    public CaisseClotureeException(LocalDate dateEcriture, LocalDate derniereCloture) {
        super(message(dateEcriture, derniereCloture));
    }

    private static String message(LocalDate dateEcriture, LocalDate derniereCloture) {
        if (dateEcriture.isEqual(derniereCloture)) {
            return "Impossible d'écrire au " + dateEcriture + " sur ce compte : la caisse a été"
                    + " comptée le jour même, ce qui arrête la journée. Si l'opération a bien eu"
                    + " lieu ce jour-là, retirez le relevé du " + derniereCloture + " depuis la"
                    + " fenêtre de comptage, saisissez-la, puis recomptez la caisse.";
        }
        return "Impossible d'écrire au " + dateEcriture + " sur ce compte : la caisse a été"
                + " comptée le " + derniereCloture + ", et tout ce qui précède ce comptage est"
                + " arrêté. Datez l'écriture du " + derniereCloture.plusDays(1) + " ou après ; si"
                + " c'est le relevé du " + derniereCloture + " qui est erroné, retirez-le pour"
                + " rouvrir la journée.";
    }
}
