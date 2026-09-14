package com.tmk.vtcmanager.application.domain.versement;

import java.util.List;
import java.util.UUID;

/**
 * Sort d'un versement dans un encaissement de masse.
 *
 * <p>Chaque versement est un tout — sa recette et sa cotisation passent
 * ensemble ou pas du tout — mais le lot, lui, n'en est pas un : un refus ne
 * concerne que le versement visé, et le guichet voit ce qui est passé.
 *
 * @param operationIds écritures produites par un versement accepté, pour le
 *                     reçu PDF ; vide sur un refus
 */
public record ResultatVersementLot(
        Long ligneRecetteId,
        Long ligneCotisationId,
        boolean succes,
        UUID versementId,
        String message,
        List<Long> operationIds
) {

    public static ResultatVersementLot reussi(SaisieVersement saisie, VersementEnregistre enregistre) {
        return new ResultatVersementLot(ligne(saisie.recette()), ligne(saisie.cotisation()),
                true, enregistre.versementId(), null, enregistre.operationIds());
    }

    public static ResultatVersementLot echec(SaisieVersement saisie, String message) {
        return new ResultatVersementLot(ligne(saisie.recette()), ligne(saisie.cotisation()),
                false, null, message, List.of());
    }

    private static Long ligne(PartVersement part) {
        return part == null ? null : part.ligneId();
    }
}
