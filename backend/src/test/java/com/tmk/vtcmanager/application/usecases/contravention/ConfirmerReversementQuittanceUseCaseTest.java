package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.domain.contravention.reversement.ResultatReversementQuittance;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ConfirmerReversementQuittanceUseCaseTest {

    private ContraventionRepository contraventionRepository;
    private ReverseContraventionUseCase reverseContraventionUseCase;
    private ConfirmerReversementQuittanceUseCase useCase;

    @BeforeEach
    void setUp() {
        contraventionRepository = mock(ContraventionRepository.class);
        reverseContraventionUseCase = mock(ReverseContraventionUseCase.class);
        useCase = new ConfirmerReversementQuittanceUseCase(
                contraventionRepository, reverseContraventionUseCase);
    }

    private static Contravention statut(Long id, ContraventionStatus statut) {
        return Contravention.builder().id(id).statut(statut).build();
    }

    @Test
    void reverse_les_eligibles_ignore_les_deja_reversees_et_introuvables() {
        when(contraventionRepository.findById(1L))
                .thenReturn(Optional.of(statut(1L, ContraventionStatus.EN_ATTENTE)));
        when(contraventionRepository.findById(2L))
                .thenReturn(Optional.of(statut(2L, ContraventionStatus.REVERSE)));
        when(contraventionRepository.findById(3L))
                .thenReturn(Optional.empty());

        // id valide, id déjà reversé, id introuvable, id null.
        ResultatReversementQuittance resultat =
                useCase.confirmer(Arrays.asList(1L, 2L, 3L, null), "LIQ-1");

        assertThat(resultat.reversees()).isEqualTo(1);
        assertThat(resultat.dejaReversees()).isEqualTo(1);
        assertThat(resultat.ignorees()).isEqualTo(2); // introuvable + null

        verify(reverseContraventionUseCase).execute(1L, "LIQ-1");
        verify(reverseContraventionUseCase, never()).execute(eq(2L), any());
        verify(reverseContraventionUseCase, never()).execute(eq(3L), any());
    }

    @Test
    void idempotent_aucun_reversement_si_toutes_deja_reversees() {
        when(contraventionRepository.findById(5L))
                .thenReturn(Optional.of(statut(5L, ContraventionStatus.REVERSE)));

        ResultatReversementQuittance resultat = useCase.confirmer(Arrays.asList(5L), "LIQ-9");

        assertThat(resultat.reversees()).isZero();
        assertThat(resultat.dejaReversees()).isEqualTo(1);
        verify(reverseContraventionUseCase, never()).execute(any(), any());
    }
}
