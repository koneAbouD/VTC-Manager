package com.tmk.vtcmanager.application.domain.finance;

import java.time.YearMonth;

/**
 * Restriction d'une lecture de la balance âgée.
 *
 * @param mois      ne retenir que les documents nés ce mois-là (null = tous) ;
 *                  l'ancienneté reste comptée depuis aujourd'hui
 * @param recherche mot-clé confronté à l'immatriculation du véhicule et au nom
 *                  du chauffeur (null ou vide = aucun)
 */
public record FiltreCreances(YearMonth mois, String recherche) {

    public static final FiltreCreances AUCUN = new FiltreCreances(null, null);

    public boolean aUneRecherche() {
        return recherche != null && !recherche.isBlank();
    }
}
