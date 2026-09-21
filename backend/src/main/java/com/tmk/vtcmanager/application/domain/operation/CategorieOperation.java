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

    /**
     * Un revenu ne peut pas être une charge, une dépense ne peut pas être un
     * produit. C'est exactement ce qui est arrivé à Vignette et Taxe, créées
     * sans nature explicite alors que la colonne avait pour défaut
     * « produit d'exploitation » : la dépense s'ajoutait aux produits du
     * véhicule au lieu d'être déduite de ses charges, et sa marge s'écartait du
     * vrai du double du montant payé.
     *
     * <p>HORS_RESULTAT reste ouvert aux deux sens : les comptes de tiers
     * (cotisations, contraventions refacturées, écarts de caisse) entrent et
     * sortent sans jamais toucher le résultat.
     *
     * <p>La base porte la même règle ({@code chk_categories_operation_sens}) ;
     * ce contrôle-ci existe pour la dire en français plutôt qu'en code SQL.
     */
    public void verifierSensCoherent() {
        if (typeOperation == null || natureResultat == null
                || natureResultat == NatureResultat.HORS_RESULTAT) {
            return;
        }
        boolean coherent = typeOperation == TypeOperation.REVENU
                ? natureResultat == NatureResultat.PRODUIT_EXPLOITATION
                : natureResultat != NatureResultat.PRODUIT_EXPLOITATION;
        if (!coherent) {
            throw new IllegalArgumentException(typeOperation == TypeOperation.REVENU
                    ? "Un revenu ne peut pas être classé en charge : choisissez "
                            + "« Produit d'exploitation » ou « Hors résultat »."
                    : "Une dépense ne peut pas être classée en produit d'exploitation : "
                            + "choisissez « Charge variable », « Charge fixe » ou "
                            + "« Hors résultat ».");
        }
    }
}
