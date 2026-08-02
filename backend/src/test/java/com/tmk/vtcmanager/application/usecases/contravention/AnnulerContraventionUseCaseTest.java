package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Une contravention annulée n'est pas effacée : elle a été due, les états
 * arrêtés pendant ce temps doivent continuer de la porter. Et l'annulation
 * s'arrête là où l'argent a bougé.
 */
class AnnulerContraventionUseCaseTest {

    private ContraventionRepository contraventionRepository;
    private AnnulerContraventionUseCase useCase;

    @BeforeEach
    void setUp() {
        contraventionRepository = mock(ContraventionRepository.class);
        AuteurCourant auteurCourant = mock(AuteurCourant.class);
        when(auteurCourant.nom()).thenReturn("gerant");
        when(contraventionRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        useCase = new AnnulerContraventionUseCase(contraventionRepository, auteurCourant);
    }

    private void contravention(Contravention.ContraventionBuilder builder) {
        when(contraventionRepository.findById(1L)).thenReturn(Optional.of(builder.build()));
    }

    private Contravention.ContraventionBuilder due() {
        return Contravention.builder()
                .id(1L)
                .dateInfraction(LocalDate.of(2026, 7, 10))
                .montant(BigDecimal.valueOf(25_000))
                .montantPaye(BigDecimal.ZERO)
                .statut(ContraventionStatus.EN_ATTENTE);
    }

    @Test
    @DisplayName("Une contravention due est annulée, datée, motivée et signée")
    void annulation_tracee() {
        contravention(due());

        Contravention resultat = useCase.execute(1L, "chauffeur non concerné");

        assertThat(resultat.getStatut()).isEqualTo(ContraventionStatus.ANNULE);
        assertThat(resultat.getMotifAnnulation()).isEqualTo("chauffeur non concerné");
        assertThat(resultat.getAnnulePar()).isEqualTo("gerant");
        assertThat(resultat.getAnnuleLe()).isNotNull();
        // La contravention reste au registre : rien n'est supprimé.
        verify(contraventionRepository, never()).deleteById(any());
    }

    @Test
    @DisplayName("Le motif est obligatoire")
    void motif_obligatoire() {
        assertThatThrownBy(() -> useCase.execute(1L, "   "))
                .isInstanceOf(IllegalArgumentException.class);
        verify(contraventionRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une contravention déjà encaissée renvoie vers l'extourne de l'encaissement")
    void versement_bloque_l_annulation() {
        contravention(due()
                .montantPaye(BigDecimal.valueOf(10_000))
                .statut(ContraventionStatus.PARTIELLEMENT_PAYE));

        assertThatThrownBy(() -> useCase.execute(1L, "erreur de saisie"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("extournez");
    }

    @Test
    @DisplayName("Une contravention reversée à l'État ne s'annule plus")
    void reversement_bloque_l_annulation() {
        contravention(due()
                .montantPaye(BigDecimal.valueOf(25_000))
                .statut(ContraventionStatus.REVERSE)
                .dateReversement(LocalDate.of(2026, 7, 20)));

        assertThatThrownBy(() -> useCase.execute(1L, "erreur de saisie"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("reversée");
    }

    @Test
    @DisplayName("Une contravention déjà annulée ne se réannule pas")
    void double_annulation_refusee() {
        contravention(due().statut(ContraventionStatus.ANNULE));

        assertThatThrownBy(() -> useCase.execute(1L, "encore"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("déjà annulée");
    }
}
