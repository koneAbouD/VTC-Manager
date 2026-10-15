package com.tmk.vtcmanager.application.domain.operation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CatalogueElementMaintenance {

    private Long id;
    private String libelle;
    private boolean actif;

    /** Montant pré-rempli à la saisie d'une maintenance (facultatif). */
    private BigDecimal montantDefaut;

    /** Nom d'objet de l'image d'illustration dans le stockage (facultatif). */
    private String image;

    /**
     * Marque de véhicule à laquelle l'élément est réservé (facultative) : sans
     * marque, l'élément est générique et proposé pour tous les véhicules.
     */
    private Long marqueId;
    private String marqueNom;

    /**
     * Modèle de véhicule auquel l'élément est réservé (facultatif) : sans
     * modèle, l'élément vaut pour tous les modèles de sa marque.
     */
    private Long modeleId;
    private String modeleNom;

    public void update(String libelle, BigDecimal montantDefaut, String image) {
        this.libelle = libelle;
        this.montantDefaut = montantDefaut;
        this.image = image;
    }

    public void affecterVehicule(Long marqueId, Long modeleId) {
        this.marqueId = marqueId;
        this.modeleId = modeleId;
    }

    /**
     * Vrai si l'élément peut être proposé pour un véhicule de cette marque et de
     * ce modèle : générique, réservé à sa marque sans précision de modèle, ou
     * réservé à son modèle exact.
     */
    public boolean estCompatibleAvec(Long marqueVehicule, Long modeleVehicule) {
        if (marqueId == null) return true;
        if (!marqueId.equals(marqueVehicule)) return false;
        return modeleId == null || modeleId.equals(modeleVehicule);
    }

    public void changerActivation(boolean actif) {
        this.actif = actif;
    }
}
