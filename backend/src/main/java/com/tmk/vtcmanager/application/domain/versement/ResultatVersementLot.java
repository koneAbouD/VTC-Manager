package com.tmk.vtcmanager.application.domain.versement;

import java.util.UUID;

/**
 * Sort d'un versement dans un encaissement de masse.
 *
 * <p>Chaque versement est un tout — sa recette et sa cotisation passent
 * ensemble ou pas du tout — mais le lot, lui, n'en est pas un : un refus ne
 * concerne que le versement visé, et le guichet voit ce qui est passé.
 */
public record ResultatVersementLot(
        Long ligneRecetteId,
        Long ligneCotisationId,
        boolean succes,
        UUID versementId,
        String message
) {

    public static ResultatVersementLot reussi(SaisieVersement saisie, UUID versementId) {
        return new ResultatVersementLot(ligne(saisie.recette()), ligne(saisie.cotisation()),
                true, versementId, null);
    }

    public static ResultatVersementLot echec(SaisieVersement saisie, String message) {
        return new ResultatVersementLot(ligne(saisie.recette()), ligne(saisie.cotisation()),
                false, null, message);
    }

    private static Long ligne(PartVersement part) {
        return part == null ? null : part.ligneId();
    }
}
