package com.tmk.vtcmanager.application.domain.operation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Élément du catalogue de maintenance : ce qui vaut pour tous les modèles de
 * véhicule — son libellé, son type de maintenance, son activation.
 *
 * <p>Ce qui dépend du modèle (prix, image, proposé ou non) est porté par ses
 * {@link TarifElementMaintenance} : un élément n'est proposé à la saisie d'une
 * maintenance que pour les modèles où il a un tarif.</p>
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CatalogueElementMaintenance {
    private Long id;
    private String libelle;
    private boolean actif;

    /**
     * Type de maintenance (catégorie de la sous-catégorie « Maintenances ») auquel
     * l'élément est réservé. Sans type, l'élément est commun : proposé quel que
     * soit le type de l'intervention (main d'œuvre, par exemple).
     */
    private Long categorieTypeId;
    private String categorieTypeLibelle;

    public void update(String libelle) {
        this.libelle = libelle;
    }

    public void affecterType(Long categorieTypeId, String categorieTypeLibelle) {
        this.categorieTypeId = categorieTypeId;
        this.categorieTypeLibelle = categorieTypeLibelle;
    }

    /**
     * Vrai si l'élément peut être proposé pour une intervention de ce type :
     * commun à tous les types, ou réservé à celui-ci. Sans type demandé, tout
     * élément convient.
     */
    public boolean estCompatibleAvecType(Long typeIntervention) {
        return typeIntervention == null
                || categorieTypeId == null
                || categorieTypeId.equals(typeIntervention);
    }

    public void changerActivation(boolean actif) {
        this.actif = actif;
    }
}
