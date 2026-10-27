package com.tmk.vtcmanager.interfaces.rest.parametrage;

import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import com.tmk.vtcmanager.interfaces.rest.parametrage.dto.ChampDescriptorResponse;
import com.tmk.vtcmanager.interfaces.rest.parametrage.dto.ReferentielDescriptorResponse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.entry;
import static org.mockito.Mockito.mock;

class ReferentielCatalogueTest {

    // findAll() du mock renvoie une liste vide par défaut → options « sous-catégorie » vides.
    private final ReferentielCatalogue catalogue =
            new ReferentielCatalogue(mock(SousCategorieOperationRepository.class));

    @Test
    void expose_les_referentiels_livres() {
        List<ReferentielDescriptorResponse> descripteurs = catalogue.descripteurs();

        assertThat(descripteurs).extracting(ReferentielDescriptorResponse::key)
                .containsExactly(
                        "types-vehicules",
                        "types-activites",
                        "marques",
                        "modeles",
                        "types-document",
                        "categories-operation",
                        "balises",
                        "types-partenaire",
                        "catalogue-elements-maintenance");
    }

    @Test
    void tous_les_referentiels_sont_editables_et_ont_un_endpoint() {
        assertThat(catalogue.descripteurs()).allSatisfy(d -> {
            assertThat(d.editable()).isTrue();
            assertThat(d.endpoint()).startsWith("/api/");
            assertThat(d.champs()).isNotEmpty();
        });
    }

    @Test
    void le_catalogue_maintenance_pointe_le_bon_endpoint() {
        ReferentielDescriptorResponse maintenance = catalogue.descripteurs().stream()
                .filter(d -> d.key().equals("catalogue-elements-maintenance"))
                .findFirst()
                .orElseThrow();

        assertThat(maintenance.endpoint()).isEqualTo("/api/catalogue-elements-maintenance");
        assertThat(maintenance.champs()).extracting("nom").contains("libelle", "actif");
    }

    @Test
    void marques_declare_une_reference_vers_les_types_vehicules() {
        ReferentielDescriptorResponse marques = catalogue.descripteurs().stream()
                .filter(d -> d.key().equals("marques"))
                .findFirst()
                .orElseThrow();

        assertThat(marques.champs())
                .anySatisfy(c -> {
                    assertThat(c.type()).isEqualTo("reference");
                    assertThat(c.refKey()).isEqualTo("types-vehicules");
                });
    }

    /**
     * Les listes déroulantes du paramétrage affichent un libellé, jamais le code
     * d'enum : « Charge fixe », pas « CHARGE_FIXE ».
     */
    @Nested
    @DisplayName("Libellés des énumérations")
    class LibellesEnumerations {

        private ChampDescriptorResponse champ(String referentiel, String nom) {
            return catalogue.descripteurs().stream()
                    .filter(r -> r.key().equals(referentiel))
                    .findFirst().orElseThrow()
                    .champs().stream()
                    .filter(c -> c.nom().equals(nom))
                    .findFirst().orElseThrow();
        }

        @Test
        @DisplayName("la nature de résultat porte un libellé par code, dans l'ordre de la liste")
        void natureResultat() {
            ChampDescriptorResponse nature = champ("categories-operation", "natureResultat");

            assertThat(nature.options()).containsExactly(
                    "PRODUIT_EXPLOITATION", "CHARGE_VARIABLE", "CHARGE_FIXE", "HORS_RESULTAT");
            assertThat(nature.libelles()).containsExactly(
                    entry("PRODUIT_EXPLOITATION", "Produit d'exploitation"),
                    entry("CHARGE_VARIABLE", "Charge variable"),
                    entry("CHARGE_FIXE", "Charge fixe"),
                    entry("HORS_RESULTAT", "Hors résultat"));
        }

        @Test
        @DisplayName("type d'opération et cible d'un document ont aussi leurs libellés")
        void autresEnumerations() {
            assertThat(champ("categories-operation", "typeOperation").libelles())
                    .containsEntry("REVENU", "Revenu")
                    .containsEntry("DEPENSE", "Dépense");
            assertThat(champ("types-document", "cible").libelles())
                    .containsEntry("VEHICULE", "Véhicule")
                    .containsEntry("CHAUFFEUR", "Chauffeur");
        }

        @Test
        @DisplayName("chaque code d'une énumération à libellés a le sien")
        void aucunCodeSansLibelle() {
            List<ChampDescriptorResponse> enums = catalogue.descripteurs().stream()
                    .flatMap(r -> r.champs().stream())
                    .filter(c -> "enum".equals(c.type()) && c.libelles() != null)
                    .toList();

            assertThat(enums).isNotEmpty();
            enums.forEach(c -> assertThat(c.libelles().keySet())
                    .as(c.nom()).containsExactlyElementsOf(c.options()));
        }
    }
}
