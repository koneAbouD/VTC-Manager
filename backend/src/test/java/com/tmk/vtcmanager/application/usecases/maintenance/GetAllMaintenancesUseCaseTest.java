package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceFiltres;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.maintenance.SyntheseMaintenances;
import com.tmk.vtcmanager.application.domain.maintenance.TotalMaintenanceParStatut;
import com.tmk.vtcmanager.application.domain.maintenance.TotalMaintenanceParType;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Lecture de la liste des maintenances et de ses compteurs. L'écran coche des
 * types et une pastille de statut ; chaque compteur doit ignorer le filtre
 * qu'il sert à choisir, sans quoi cocher la vidange ferait disparaître les
 * autres tuiles, et choisir « Terminées » mettrait les autres pastilles à zéro.
 */
class GetAllMaintenancesUseCaseTest {

    private static final LocalDate AUJOURDHUI = LocalDate.of(2026, 10, 29);
    private static final Long VIDANGE = 3L;
    private static final Long PNEUS = 7L;

    private MaintenanceRepository repository;
    private GetAllMaintenancesUseCase useCase;

    @BeforeEach
    void setUp() {
        repository = mock(MaintenanceRepository.class);
        useCase = new GetAllMaintenancesUseCase(repository, () -> AUJOURDHUI);
    }

    private static MaintenanceFiltres filtres(MaintenanceStatus statut, List<Long> types,
                                              boolean enRetard) {
        return new MaintenanceFiltres(LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31),
                statut, 12L, "koné", types, enRetard);
    }

    @Nested
    @DisplayName("Page de la liste")
    class Page {

        @Test
        @DisplayName("transmet les filtres tels quels avec le jour courant comme référence du retard")
        void transmetFiltresEtJour() {
            var demande = filtres(null, List.of(VIDANGE), true);
            PageResult<Maintenance> attendu = new PageResult<>(List.of(), 0, 20, 0);
            when(repository.findPageByFiltres(demande, AUJOURDHUI, 0, 20)).thenReturn(attendu);

            assertThat(useCase.executePage(demande, 0, 20)).isSameAs(attendu);
        }
    }

    @Nested
    @DisplayName("Synthèse")
    class Synthese {

        @BeforeEach
        void reponsesVides() {
            when(repository.totauxParType(any())).thenReturn(List.of());
            when(repository.totauxParStatut(any())).thenReturn(List.of());
        }

        @Test
        @DisplayName("les tuiles de types ignorent le type coché, le statut et le retard")
        void tuilesSansFiltreDeType() {
            useCase.synthese(filtres(MaintenanceStatus.TERMINEE, List.of(VIDANGE), true));

            ArgumentCaptor<MaintenanceFiltres> captor = ArgumentCaptor.forClass(MaintenanceFiltres.class);
            verify(repository).totauxParType(captor.capture());
            MaintenanceFiltres utilises = captor.getValue();
            assertThat(utilises.categorieTypeIds()).isEmpty();
            assertThat(utilises.statut()).isNull();
            assertThat(utilises.enRetard()).isFalse();
            // La période, le véhicule et la recherche, eux, s'appliquent.
            assertThat(utilises.vehiculeId()).isEqualTo(12L);
            assertThat(utilises.recherche()).isEqualTo("koné");
            assertThat(utilises.dateDebut()).isEqualTo(LocalDate.of(2026, 10, 1));
        }

        @Test
        @DisplayName("les pastilles de statut suivent les types cochés mais pas le statut choisi")
        void pastillesSuiventLesTypes() {
            useCase.synthese(filtres(MaintenanceStatus.TERMINEE, List.of(VIDANGE, PNEUS), true));

            ArgumentCaptor<MaintenanceFiltres> captor = ArgumentCaptor.forClass(MaintenanceFiltres.class);
            verify(repository).totauxParStatut(captor.capture());
            assertThat(captor.getValue().categorieTypeIds()).containsExactly(VIDANGE, PNEUS);
            assertThat(captor.getValue().statut()).isNull();
            assertThat(captor.getValue().enRetard()).isFalse();
        }

        @Test
        @DisplayName("tous les statuts sont servis, à zéro quand aucune intervention ne les porte")
        void tousLesStatutsServis() {
            when(repository.totauxParStatut(any())).thenReturn(List.of(
                    new TotalMaintenanceParStatut(MaintenanceStatus.TERMINEE, 11)));

            SyntheseMaintenances synthese = useCase.synthese(filtres(null, List.of(), false));

            assertThat(synthese.parStatut())
                    .extracting(TotalMaintenanceParStatut::statut)
                    .containsExactly(MaintenanceStatus.values());
            assertThat(synthese.parStatut())
                    .filteredOn(t -> t.statut() == MaintenanceStatus.TERMINEE)
                    .singleElement()
                    .extracting(TotalMaintenanceParStatut::nombre)
                    .isEqualTo(11L);
            assertThat(synthese.parStatut())
                    .filteredOn(t -> t.statut() != MaintenanceStatus.TERMINEE)
                    .allSatisfy(t -> assertThat(t.nombre()).isZero());
        }

        @Test
        @DisplayName("le retard se compte sur les types cochés, au jour courant, quel que soit le statut choisi")
        void retardCompteSurLesTypes() {
            when(repository.compter(any(), eq(AUJOURDHUI))).thenReturn(3L);

            SyntheseMaintenances synthese =
                    useCase.synthese(filtres(MaintenanceStatus.ANNULEE, List.of(VIDANGE), false));

            ArgumentCaptor<MaintenanceFiltres> captor = ArgumentCaptor.forClass(MaintenanceFiltres.class);
            verify(repository).compter(captor.capture(), eq(AUJOURDHUI));
            assertThat(captor.getValue().enRetard()).isTrue();
            assertThat(captor.getValue().statut()).isNull();
            assertThat(captor.getValue().categorieTypeIds()).containsExactly(VIDANGE);
            assertThat(synthese.enRetard()).isEqualTo(3L);
        }

        @Test
        @DisplayName("les types se présentent du plus fréquent au moins fréquent, puis par libellé")
        void typesParFrequence() {
            when(repository.totauxParType(any())).thenReturn(List.of(
                    new TotalMaintenanceParType(1L, "TOLERIE", "Tôlerie", 2, BigDecimal.TEN),
                    new TotalMaintenanceParType(PNEUS, "PNEUMATIQUE", "Pneumatiques", 9, BigDecimal.ONE),
                    new TotalMaintenanceParType(VIDANGE, "VIDANGE", "Vidange", 14, BigDecimal.ONE),
                    new TotalMaintenanceParType(2L, "FREINAGE", "Freinage", 2, BigDecimal.ONE)));

            SyntheseMaintenances synthese = useCase.synthese(filtres(null, List.of(), false));

            assertThat(synthese.parType())
                    .extracting(TotalMaintenanceParType::libelle)
                    .containsExactly("Vidange", "Pneumatiques", "Freinage", "Tôlerie");
        }
    }

    @Test
    @DisplayName("un type sans intervention terminée a un coût réalisé nul, jamais absent")
    void coutRealiseJamaisNul() {
        // SUM sur des lignes sans coût renvoie NULL : la tuile doit afficher 0.
        assertThat(new TotalMaintenanceParType(VIDANGE, "VIDANGE", "Vidange", 3, null).coutRealise())
                .isEqualByComparingTo(BigDecimal.ZERO);
    }
}
