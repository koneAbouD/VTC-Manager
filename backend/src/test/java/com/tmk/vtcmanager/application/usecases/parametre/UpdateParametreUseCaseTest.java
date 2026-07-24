package com.tmk.vtcmanager.application.usecases.parametre;

import com.tmk.vtcmanager.application.domain.parametre.ParametreCles;
import com.tmk.vtcmanager.application.domain.parametre.ParametreGeneral;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ParametreGeneralRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class UpdateParametreUseCaseTest {

    private ParametreGeneralRepository repository;
    private UpdateParametreUseCase useCase;

    @BeforeEach
    void setUp() {
        repository = mock(ParametreGeneralRepository.class);
        useCase = new UpdateParametreUseCase(repository);
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    private void existeAmortissement() {
        when(repository.findByCle(ParametreCles.DUREE_AMORTISSEMENT_MOIS))
                .thenReturn(Optional.of(ParametreGeneral.builder()
                        .cle(ParametreCles.DUREE_AMORTISSEMENT_MOIS)
                        .valeur("60")
                        .libelle("Durée d'amortissement")
                        .build()));
    }

    @Test
    void executer_met_a_jour_une_duree_valide() {
        existeAmortissement();

        ParametreGeneral maj =
                useCase.executer(ParametreCles.DUREE_AMORTISSEMENT_MOIS, " 48 ");

        assertThat(maj.getValeur()).isEqualTo("48");
    }

    @Test
    void executer_rejette_une_valeur_non_numerique() {
        existeAmortissement();

        assertThatThrownBy(() ->
                useCase.executer(ParametreCles.DUREE_AMORTISSEMENT_MOIS, "cinq ans"))
                .isInstanceOf(IllegalArgumentException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void executer_rejette_une_duree_inferieure_a_un_mois() {
        existeAmortissement();

        assertThatThrownBy(() ->
                useCase.executer(ParametreCles.DUREE_AMORTISSEMENT_MOIS, "0"))
                .isInstanceOf(IllegalArgumentException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void executer_leve_not_found_si_cle_inconnue() {
        when(repository.findByCle("INCONNU")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.executer("INCONNU", "10"))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
