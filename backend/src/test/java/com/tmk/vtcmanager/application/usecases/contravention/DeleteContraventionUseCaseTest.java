package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * La suppression reste ouverte à la saisie qui n'a rien produit, et fermée dès
 * qu'un mouvement d'argent s'y rattache.
 */
class DeleteContraventionUseCaseTest {

    private ContraventionRepository contraventionRepository;
    private DeleteContraventionUseCase useCase;

    @BeforeEach
    void setUp() {
        contraventionRepository = mock(ContraventionRepository.class);
        useCase = new DeleteContraventionUseCase(contraventionRepository);
    }

    private void contravention(Contravention.ContraventionBuilder builder) {
        when(contraventionRepository.findById(1L)).thenReturn(Optional.of(builder.build()));
    }

    private Contravention.ContraventionBuilder due() {
        return Contravention.builder()
                .id(1L)
                .montant(BigDecimal.valueOf(25_000))
                .montantPaye(BigDecimal.ZERO)
                .statut(ContraventionStatus.EN_ATTENTE);
    }

    @Test
    @DisplayName("Une contravention jamais encaissée peut être supprimée")
    void suppression_possible_sans_mouvement() {
        contravention(due());

        useCase.execute(1L);

        verify(contraventionRepository).deleteById(1L);
    }

    @Test
    @DisplayName("Une contravention encaissée renvoie vers l'annulation")
    void suppression_refusee_apres_versement() {
        contravention(due().montantPaye(BigDecimal.valueOf(10_000)));

        assertThatThrownBy(() -> useCase.execute(1L))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("annulez-la");
        verify(contraventionRepository, never()).deleteById(any());
    }

    @Test
    @DisplayName("Une contravention reversée à l'État renvoie vers l'annulation")
    void suppression_refusee_apres_reversement() {
        contravention(due().dateReversement(LocalDate.of(2026, 7, 20)));

        assertThatThrownBy(() -> useCase.execute(1L))
                .isInstanceOf(IllegalStateException.class);
        verify(contraventionRepository, never()).deleteById(any());
    }
}
