package com.tmk.vtcmanager.interfaces.rest.parametrage;

import com.tmk.vtcmanager.interfaces.rest.parametrage.dto.ReferentielDescriptorResponse;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class ReferentielCatalogueTest {

    private final ReferentielCatalogue catalogue = new ReferentielCatalogue();

    @Test
    void expose_les_referentiels_livres() {
        List<ReferentielDescriptorResponse> descripteurs = catalogue.descripteurs();

        assertThat(descripteurs).extracting(ReferentielDescriptorResponse::key)
                .containsExactly(
                        "types-vehicules",
                        "types-activites",
                        "marques",
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
}
