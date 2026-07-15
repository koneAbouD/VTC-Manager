package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;

import java.util.Set;

/**
 * Sélection de lignes pour un arrêté <b>partiel</b> : quelles cotisations entrent
 * dans le fonds restitué et quelles créances sont compensées. Un ensemble
 * {@code null} signifie « toutes » (arrêté total, comportement historique) ;
 * l'ensemble des créances vide signifie « aucune compensation ».
 *
 * @param cotisationIds identifiants des lignes de cotisation à restituer, ou {@code null} pour toutes.
 * @param creances      clés des créances à compenser, ou {@code null} pour toutes.
 */
public record SelectionArrete(Set<Long> cotisationIds, Set<CreanceKey> creances) {

    /** Identité d'une créance dans une sélection : type de document + id du document. */
    public record CreanceKey(TypeDocumentCreance document, Long documentId) {}

    /** Sélection totale : toutes les cotisations et toutes les créances (arrêté classique). */
    public static SelectionArrete tout() {
        return new SelectionArrete(null, null);
    }

    /** Vrai si la cotisation est retenue dans le fonds à restituer. */
    public boolean cotisationIncluse(LigneCotisation cotisation) {
        return cotisationIds == null || cotisationIds.contains(cotisation.getId());
    }

    /** Vrai si la créance doit être compensée par le fonds. */
    public boolean creanceIncluse(LigneCreance creance) {
        return creances == null
                || creances.contains(new CreanceKey(creance.getDocument(), creance.getDocumentId()));
    }
}
