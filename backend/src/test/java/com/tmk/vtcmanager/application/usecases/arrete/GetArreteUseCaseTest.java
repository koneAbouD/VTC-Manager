package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.finance.CompteCourant;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class GetArreteUseCaseTest {

    private ArreteCompteRepository arreteCompteRepository;
    private CompteCourantRepository compteCourantRepository;
    private GetArreteUseCase useCase;

    @BeforeEach
    void setUp() {
        arreteCompteRepository = mock(ArreteCompteRepository.class);
        compteCourantRepository = mock(CompteCourantRepository.class);
        useCase = new GetArreteUseCase(arreteCompteRepository, compteCourantRepository);
    }

    @Test
    void lister_sans_filtre_ne_borne_pas_les_dates() {
        when(arreteCompteRepository.findAll(null, null)).thenReturn(List.of());

        useCase.lister();

        verify(arreteCompteRepository).findAll(null, null);
    }

    @Test
    void lister_par_mois_borne_sur_le_mois_entier() {
        useCase.lister(2026, 2);

        verify(arreteCompteRepository).findAll(LocalDate.of(2026, 2, 1), LocalDate.of(2026, 2, 28));
    }

    @Test
    void lister_par_mois_gere_les_annees_bissextiles() {
        useCase.lister(2024, 2);

        verify(arreteCompteRepository).findAll(LocalDate.of(2024, 2, 1), LocalDate.of(2024, 2, 29));
    }

    @Test
    void lister_par_annee_seule_borne_sur_l_annee_entiere() {
        useCase.lister(2026, null);

        verify(arreteCompteRepository).findAll(LocalDate.of(2026, 1, 1), LocalDate.of(2026, 12, 31));
    }

    @Test
    void lister_refuse_un_mois_sans_annee() {
        assertThatThrownBy(() -> useCase.lister(null, 3))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("année");
    }

    @Test
    void lister_refuse_un_mois_hors_intervalle() {
        assertThatThrownBy(() -> useCase.lister(2026, 13))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Mois invalide");
    }

    @Test
    void detail_enrichit_le_reste_avec_le_solde_courant_du_perimetre() {
        ArreteCompte arrete = ArreteCompte.builder()
                .id(7L)
                .perimetre(PerimetreArrete.CHAUFFEUR)
                .perimetreId(3L)
                .build();
        when(arreteCompteRepository.findById(7L)).thenReturn(Optional.of(arrete));
        when(compteCourantRepository.getComptesCourantsParChauffeur()).thenReturn(List.of(
                CompteCourant.builder().tiersId(9L).net(new BigDecimal("1000")).build(),
                CompteCourant.builder().tiersId(3L).net(new BigDecimal("2500")).build()));

        ArreteCompte resultat = useCase.detail(7L).orElseThrow();

        assertThat(resultat.getResteNet()).isEqualByComparingTo("2500");
    }

    @Test
    void detail_met_le_reste_a_zero_quand_le_perimetre_n_a_plus_de_compte() {
        ArreteCompte arrete = ArreteCompte.builder()
                .id(8L)
                .perimetre(PerimetreArrete.VEHICULE)
                .perimetreId(4L)
                .build();
        when(arreteCompteRepository.findById(8L)).thenReturn(Optional.of(arrete));
        when(compteCourantRepository.getComptesCourantsParVehicule()).thenReturn(List.of());

        ArreteCompte resultat = useCase.detail(8L).orElseThrow();

        assertThat(resultat.getResteNet()).isEqualByComparingTo("0");
    }
}
