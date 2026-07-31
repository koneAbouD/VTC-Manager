package com.tmk.vtcmanager.application.domain.partenaire;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Nature d'un partenaire — prestataire, fournisseur, administration, bailleur…
 *
 * <p>C'était un enum de code : ajouter une famille imposait un redéploiement.
 * La nature est désormais une donnée de référence, paramétrable au même titre
 * que les types de véhicule ou de document.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TypePartenaire {

    private Long id;
    private String nom;
    private String description;
    private boolean actif;

    public static TypePartenaire create(String nom, String description) {
        return TypePartenaire.builder()
                .nom(nom)
                .description(description)
                .actif(true)
                .build();
    }

    public void update(String nom, String description) {
        this.nom = nom;
        this.description = description;
    }

    public void changerActivation(boolean actif) {
        this.actif = actif;
    }
}
