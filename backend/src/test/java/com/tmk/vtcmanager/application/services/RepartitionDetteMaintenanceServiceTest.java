package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Qui doit quoi : la règle qui départage les prestataires d'une intervention. */
class RepartitionDetteMaintenanceServiceTest {

    private final RepartitionDetteMaintenanceService service =
            new RepartitionDetteMaintenanceService();

    @Test
    @DisplayName("Lignes toutes attribuées : chacun sa part, sans partenaire principal")
    void toutes_les_lignes_attribuees() {
        Map<Long, BigDecimal> parts = service.repartir(maintenance(null, "50000",
                element("Main d'œuvre", "30000", partenaire(1L)),
                element("Plaquettes", "20000", partenaire(2L))));

        assertThat(parts).containsExactly(
                Map.entry(1L, new BigDecimal("30000")),
                Map.entry(2L, new BigDecimal("20000")));
    }

    @Test
    @DisplayName("Remise globale sans partenaire principal : étalée au prorata")
    void remise_repartie_au_prorata() {
        // 45 000 pour 50 000 de lignes : 5 000 de remise, 60/40 entre les deux.
        Map<Long, BigDecimal> parts = service.repartir(maintenance(null, "45000",
                element("Main d'œuvre", "30000", partenaire(1L)),
                element("Plaquettes", "20000", partenaire(2L))));

        assertThat(parts.get(1L)).isEqualByComparingTo("27000");
        assertThat(parts.get(2L)).isEqualByComparingTo("18000");
        assertThat(parts.values().stream().reduce(BigDecimal.ZERO, BigDecimal::add))
                .isEqualByComparingTo("45000");
    }

    @Test
    @DisplayName("Le reliquat d'arrondi ne se perd pas en route")
    void somme_exacte_malgre_les_arrondis() {
        Map<Long, BigDecimal> parts = service.repartir(maintenance(null, "10000",
                element("A", "3333", partenaire(1L)),
                element("B", "3333", partenaire(2L)),
                element("C", "3334", partenaire(3L))));

        assertThat(parts.values().stream().reduce(BigDecimal.ZERO, BigDecimal::add))
                .isEqualByComparingTo("10000");
    }

    @Test
    @DisplayName("Écart absorbé par le partenaire de l'intervention quand il existe")
    void ecart_au_partenaire_principal() {
        Map<Long, BigDecimal> parts = service.repartir(maintenance(partenaire(9L), "55000",
                element("Main d'œuvre", "30000", partenaire(1L)),
                element("Plaquettes", "20000", partenaire(2L))));

        assertThat(parts.get(9L)).isEqualByComparingTo("5000");
        assertThat(parts.get(1L)).isEqualByComparingTo("30000");
    }

    @Test
    @DisplayName("Coût absent : l'intervention vaut ses lignes, rien n'est effacé")
    void cout_absent_vaut_les_lignes() {
        Maintenance sansCout = Maintenance.builder()
                .id(1L)
                .cout(null)
                .detailMaintenance(DetailMaintenance.builder()
                        .elements(List.of(
                                element("Main d'œuvre", "22000", partenaire(1L)),
                                element("Plaquettes", "25000", partenaire(2L))))
                        .build())
                .build();

        Map<Long, BigDecimal> parts = service.repartir(sansCout);

        assertThat(parts.get(1L)).isEqualByComparingTo("22000");
        assertThat(parts.get(2L)).isEqualByComparingTo("25000");
    }

    @Test
    @DisplayName("Sans aucune ligne ni partenaire, la dette n'a pas de créancier")
    void sans_ligne_ni_partenaire() {
        assertThatThrownBy(() -> service.repartir(maintenance(null, "25000")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("partenaire de l'intervention");
    }

    // ── Fixtures ─────────────────────────────────────────────────────────

    private static Maintenance maintenance(Partenaire principal, String cout,
                                           ElementMaintenance... elements) {
        return Maintenance.builder()
                .id(1L)
                .cout(new BigDecimal(cout))
                .partenaire(principal)
                .detailMaintenance(DetailMaintenance.builder()
                        .elements(List.of(elements)).build())
                .build();
    }

    private static Partenaire partenaire(Long id) {
        return Partenaire.builder().id(id).nom("Partenaire " + id).build();
    }

    private static ElementMaintenance element(String libelle, String montant, Partenaire p) {
        return ElementMaintenance.builder()
                .libelle(libelle)
                .montant(new BigDecimal(montant))
                .partenaire(p)
                .build();
    }
}
