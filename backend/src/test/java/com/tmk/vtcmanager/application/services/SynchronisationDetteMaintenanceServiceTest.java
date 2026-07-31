package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.DetailMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementMaintenance;
import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.domain.partenaire.StatutFacturePartenaire;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.usecases.partenaire.EnregistrerFactureUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Corriger une intervention doit se voir aussitôt dans l'échéancier — sans
 * jamais effacer un règlement déjà encaissé.
 */
class SynchronisationDetteMaintenanceServiceTest {

    private static final LocalDate LE_10_MARS = LocalDate.of(2026, 3, 10);
    private static final LocalDate FIN_MARS = LocalDate.of(2026, 3, 31);

    private FacturePartenaireRepository factureRepository;
    private EnregistrerFactureUseCase enregistrerFactureUseCase;
    private SynchronisationDetteMaintenanceService service;

    @BeforeEach
    void setUp() {
        factureRepository = mock(FacturePartenaireRepository.class);
        enregistrerFactureUseCase = mock(EnregistrerFactureUseCase.class);
        when(factureRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        service = new SynchronisationDetteMaintenanceService(
                factureRepository, enregistrerFactureUseCase,
                new RepartitionDetteMaintenanceService());
    }

    @Test
    @DisplayName("Coût revu à la hausse : la dette existante suit, sans doublon")
    void cout_modifie_ajuste_la_dette() {
        dettes(dette(1L, 1L, "Garage Koné", "30000", "0"));

        service.synchroniser(maintenance(partenaire(1L, "Garage Koné"),
                List.of(element("Main d'œuvre", "45000", null)), "45000"));

        ArgumentCaptor<FacturePartenaire> saved = ArgumentCaptor.forClass(FacturePartenaire.class);
        verify(factureRepository).save(saved.capture());
        assertThat(saved.getValue().getMontant()).isEqualByComparingTo("45000");
        assertThat(saved.getValue().getStatut()).isEqualTo(StatutFacturePartenaire.A_PAYER);
        verify(enregistrerFactureUseCase, never()).executer(any());
    }

    @Test
    @DisplayName("Ligne confiée à un autre prestataire : sa dette apparaît")
    void nouveau_partenaire_cree_une_dette() {
        dettes(dette(1L, 1L, "Garage Koné", "50000", "0"));

        service.synchroniser(maintenance(partenaire(1L, "Garage Koné"),
                List.of(element("Main d'œuvre", "30000", null),
                        element("Plaquettes", "20000", partenaire(2L, "Pièces Auto CI"))),
                "50000"));

        ArgumentCaptor<FacturePartenaire> creee = ArgumentCaptor.forClass(FacturePartenaire.class);
        verify(enregistrerFactureUseCase).executer(creee.capture());
        assertThat(creee.getValue().getPartenaire().getId()).isEqualTo(2L);
        assertThat(creee.getValue().getMontant()).isEqualByComparingTo("20000");
        assertThat(creee.getValue().getDateEcheance()).isEqualTo(FIN_MARS);

        ArgumentCaptor<FacturePartenaire> ajustee = ArgumentCaptor.forClass(FacturePartenaire.class);
        verify(factureRepository).save(ajustee.capture());
        assertThat(ajustee.getValue().getMontant()).isEqualByComparingTo("30000");
    }

    @Test
    @DisplayName("Prestataire retiré : sa dette est annulée, pas laissée ouverte")
    void partenaire_retire_annule_sa_dette() {
        dettes(dette(1L, 1L, "Garage Koné", "30000", "0"),
                dette(2L, 2L, "Pièces Auto CI", "20000", "0"));

        service.synchroniser(maintenance(partenaire(1L, "Garage Koné"),
                List.of(element("Main d'œuvre", "50000", null)), "50000"));

        ArgumentCaptor<FacturePartenaire> saved = ArgumentCaptor.forClass(FacturePartenaire.class);
        verify(factureRepository, org.mockito.Mockito.times(2)).save(saved.capture());

        FacturePartenaire annulee = saved.getAllValues().stream()
                .filter(f -> f.getId().equals(2L)).findFirst().orElseThrow();
        assertThat(annulee.getStatut()).isEqualTo(StatutFacturePartenaire.ANNULEE);
        assertThat(annulee.getMotifAnnulation()).contains("n'y figure plus");
    }

    @Test
    @DisplayName("Dette déjà réglée en partie : impossible de la ramener sous le montant payé")
    void refuse_de_descendre_sous_le_montant_paye() {
        dettes(dette(1L, 1L, "Garage Koné", "50000", "40000"));

        assertThatThrownBy(() -> service.synchroniser(maintenance(partenaire(1L, "Garage Koné"),
                List.of(element("Main d'œuvre", "30000", null)), "30000")))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Extournez");
    }

    @Test
    @DisplayName("Prestataire réglé puis retiré : l'annulation est refusée")
    void refuse_d_annuler_une_dette_reglee() {
        dettes(dette(1L, 1L, "Garage Koné", "30000", "0"),
                dette(2L, 2L, "Pièces Auto CI", "20000", "20000"));

        assertThatThrownBy(() -> service.synchroniser(maintenance(partenaire(1L, "Garage Koné"),
                List.of(element("Main d'œuvre", "50000", null)), "50000")))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("extournez le règlement");
    }

    @Test
    @DisplayName("Plus rien à répartir : on refuse plutôt que d'effacer le passif")
    void cible_vide_ne_supprime_pas_les_dettes() {
        dettes(dette(1L, 1L, "Garage Koné", "22000", "0"),
                dette(2L, 2L, "Pièces Auto CI", "25000", "0"));

        Maintenance sansRien = Maintenance.builder()
                .id(1L)
                .type("FREINAGE")
                .dateEffectuee(LE_10_MARS)
                .cout(null)
                .partenaire(partenaire(1L, "Garage Koné"))
                .detailMaintenance(DetailMaintenance.builder().elements(List.of()).build())
                .build();

        assertThatThrownBy(() -> service.synchroniser(sansRien))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("plus aucun montant");

        verify(factureRepository, never()).save(any());
    }

    @Test
    @DisplayName("Intervention réglée comptant : rien à synchroniser")
    void sans_dette_ne_fait_rien() {
        when(factureRepository.findByMaintenanceId(anyLong())).thenReturn(List.of());

        service.synchroniser(maintenance(partenaire(1L, "Garage Koné"),
                List.of(element("Main d'œuvre", "50000", null)), "50000"));

        verify(factureRepository, never()).save(any());
        verify(enregistrerFactureUseCase, never()).executer(any());
    }

    // ── Fixtures ─────────────────────────────────────────────────────────

    private void dettes(FacturePartenaire... dettes) {
        when(factureRepository.findByMaintenanceId(1L)).thenReturn(List.of(dettes));
    }

    private static FacturePartenaire dette(Long id, Long partenaireId, String nom,
                                           String montant, String paye) {
        return FacturePartenaire.builder()
                .id(id)
                .partenaire(partenaire(partenaireId, nom))
                .montant(new BigDecimal(montant))
                .montantPaye(new BigDecimal(paye))
                .dateFacture(LE_10_MARS)
                .dateEcheance(FIN_MARS)
                .statut(StatutFacturePartenaire.A_PAYER)
                .maintenanceId(1L)
                .build();
    }

    private static Maintenance maintenance(Partenaire principal,
                                           List<ElementMaintenance> elements, String cout) {
        return Maintenance.builder()
                .id(1L)
                .type("VIDANGE")
                .dateEffectuee(LE_10_MARS)
                .cout(new BigDecimal(cout))
                .partenaire(principal)
                .detailMaintenance(DetailMaintenance.builder().elements(elements).build())
                .build();
    }

    private static Partenaire partenaire(Long id, String nom) {
        return Partenaire.builder().id(id).nom(nom).build();
    }

    private static ElementMaintenance element(String libelle, String montant, Partenaire p) {
        return ElementMaintenance.builder()
                .libelle(libelle)
                .montant(new BigDecimal(montant))
                .partenaire(p)
                .build();
    }
}
