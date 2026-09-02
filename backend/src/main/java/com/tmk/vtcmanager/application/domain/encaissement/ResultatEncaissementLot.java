package com.tmk.vtcmanager.application.domain.encaissement;

/**
 * Sort d'une ligne dans un encaissement de masse.
 *
 * <p>Le lot n'est pas un tout ou rien : une période clôturée, une caisse déjà
 * comptée ou un mode de paiement non autorisé ne concernent que la ligne
 * visée. Chacune rend donc son propre verdict, et le guichet voit d'un coup
 * d'œil ce qui est passé et ce qu'il reste à traiter.
 */
public record ResultatEncaissementLot(
        Long ligneId,
        boolean succes,
        Long encaissementId,
        String message
) {

    public static ResultatEncaissementLot reussi(Long ligneId, Long encaissementId) {
        return new ResultatEncaissementLot(ligneId, true, encaissementId, null);
    }

    public static ResultatEncaissementLot echec(Long ligneId, String message) {
        return new ResultatEncaissementLot(ligneId, false, null, message);
    }
}
