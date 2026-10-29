package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import java.math.BigDecimal;
import java.util.List;

/**
 * Élément du catalogue de maintenance.
 *
 * <p>Quand la demande désigne un modèle (onglet du paramétrage, saisie d'une
 * maintenance pour un véhicule), {@code montantDefaut}, {@code image},
 * {@code imageUrl} et {@code tarifActif} sont ceux de ce modèle : la saisie
 * pré-remplit ainsi le bon prix et montre la bonne image. Sans modèle, ils sont
 * nuls. {@code tarifs} donne le détail de tous les modèles.</p>
 */
public record CatalogueElementMaintenanceResponse(
        Long id,
        String libelle,
        boolean actif,
        // Type de maintenance réservé (null : élément commun à tous les types).
        Long categorieTypeId,
        String categorieTypeLibelle,
        // Modèle dont les champs ci-dessous sont tirés (null sans modèle demandé).
        Long tarifModeleId,
        BigDecimal montantDefaut,
        // Nom d'objet de l'image (à renvoyer tel quel lors d'une mise à jour).
        String image,
        // URL présignée temporaire pour afficher l'image (null si aucune image).
        String imageUrl,
        Boolean tarifActif,
        List<TarifResponse> tarifs
) {

    public record TarifResponse(
            Long id,
            Long modeleId,
            String modeleNom,
            Long marqueId,
            String marqueNom,
            BigDecimal prix,
            String image,
            String imageUrl,
            boolean actif) {
    }
}
