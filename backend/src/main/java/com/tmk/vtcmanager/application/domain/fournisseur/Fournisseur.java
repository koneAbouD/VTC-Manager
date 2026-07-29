package com.tmk.vtcmanager.application.domain.fournisseur;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Tiers auprès de qui l'entreprise achète à crédit. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Fournisseur {

    private Long id;
    private String nom;
    private TypeFournisseur type;
    private String telephone;
    private String email;
    private String adresse;
    /** Compte contribuable : le cabinet en a besoin pour justifier la charge. */
    private String numeroCompteContribuable;
    private String commentaire;
    private boolean actif;
}
