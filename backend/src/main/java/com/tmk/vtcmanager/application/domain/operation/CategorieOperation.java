package com.tmk.vtcmanager.application.domain.operation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CategorieOperation {

    private Long id;
    private String code;
    private String libelle;
    private TypeOperation typeOperation;
    private NatureResultat natureResultat;
    /** Compte du plan comptable (SYSCOHADA) pour l'export ; null si non mappé. */
    private String compteComptable;
    private boolean actif;
    private SousCategorieOperation sousCategorie;
}
