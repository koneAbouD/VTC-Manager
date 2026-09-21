package com.tmk.vtcmanager.application.domain.operation;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Le sens d'une catégorie ne se contredit pas.
 *
 * <p>Vignette et Taxe, deux dépenses, ont vécu classées « produit
 * d'exploitation » parce qu'elles avaient été créées sans nature explicite
 * alors que la colonne en avait une par défaut. Une vignette payée pour un
 * véhicule s'ajoutait à ses produits au lieu d'être déduite de ses charges :
 * sa marge s'écartait du vrai de deux fois le montant payé, et le classement de
 * la flotte s'en trouvait inversé. Ces cas disent la règle qui l'empêche.
 */
class CategorieOperationSensTest {

    private static CategorieOperation categorie(TypeOperation type, NatureResultat nature) {
        return CategorieOperation.builder()
                .code("VIGNETTE")
                .libelle("Vignette")
                .typeOperation(type)
                .natureResultat(nature)
                .build();
    }

    @Test
    @DisplayName("Une dépense ne peut pas être un produit d'exploitation")
    void depense_en_produit_refusee() {
        assertThatThrownBy(() -> categorie(TypeOperation.DEPENSE,
                NatureResultat.PRODUIT_EXPLOITATION).verifierSensCoherent())
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("dépense");
    }

    @Test
    @DisplayName("Un revenu ne peut pas être une charge")
    void revenu_en_charge_refuse() {
        assertThatThrownBy(() -> categorie(TypeOperation.REVENU,
                NatureResultat.CHARGE_VARIABLE).verifierSensCoherent())
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("revenu");
    }

    @Test
    @DisplayName("Les deux sens d'une charge sont ouverts à une dépense")
    void depense_en_charge_acceptee() {
        assertThatCode(() -> categorie(TypeOperation.DEPENSE,
                NatureResultat.CHARGE_FIXE).verifierSensCoherent())
                .doesNotThrowAnyException();
        assertThatCode(() -> categorie(TypeOperation.DEPENSE,
                NatureResultat.CHARGE_VARIABLE).verifierSensCoherent())
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Hors résultat reste ouvert aux deux sens : c'est un compte de tiers")
    void hors_resultat_accepte_les_deux_sens() {
        // Une cotisation entre puis ressort, une contravention est avancée puis
        // refacturée : dans les deux sens, le résultat n'est jamais touché.
        assertThatCode(() -> categorie(TypeOperation.REVENU,
                NatureResultat.HORS_RESULTAT).verifierSensCoherent())
                .doesNotThrowAnyException();
        assertThatCode(() -> categorie(TypeOperation.DEPENSE,
                NatureResultat.HORS_RESULTAT).verifierSensCoherent())
                .doesNotThrowAnyException();
    }
}
