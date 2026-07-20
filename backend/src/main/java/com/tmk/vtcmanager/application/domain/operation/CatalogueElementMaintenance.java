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

    public void update(String libelle, BigDecimal montantDefaut, String image) {
        this.libelle = libelle;
        this.montantDefaut = montantDefaut;
        this.image = image;
    }

    public void changerActivation(boolean actif) {
        this.actif = actif;
    }
}
