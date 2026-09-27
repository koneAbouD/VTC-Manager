package com.tmk.vtcmanager.application.domain.cotisation;

/**
 * Sort d'une ligne dans une annulation de masse. Comme l'encaissement en lot,
 * ce n'est pas un tout ou rien : une ligne qui détient encore du fonds est
 * refusée seule, avec un motif rédigé pour l'écran.
 */
public record ResultatAnnulationLot(Long ligneId, boolean succes, String message) {

    public static ResultatAnnulationLot reussi(Long ligneId) {
        return new ResultatAnnulationLot(ligneId, true, null);
    }

    public static ResultatAnnulationLot echec(Long ligneId, String message) {
        return new ResultatAnnulationLot(ligneId, false, message);
    }
}
