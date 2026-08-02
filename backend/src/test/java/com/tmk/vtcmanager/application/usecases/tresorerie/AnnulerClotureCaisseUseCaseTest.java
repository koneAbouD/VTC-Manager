package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.usecases.operationFinanciere.AnnulerOperationFinanciereUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Retrait d'un relevé de caisse erroné.
 *
 * <p>Le procès-verbal n'est jamais supprimé : il cesse de faire foi, ce qui
 * rouvre la journée au recomptage — sans quoi un comptage saisi à la mauvaise
 * date rendrait la clôture du mois concerné définitivement impossible.
 */
class AnnulerClotureCaisseUseCaseTest {

    private static final LocalDate JOUR = LocalDate.of(2026, 8, 2);

    private ClotureCaisseRepository clotureCaisseRepository;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private AnnulerOperationFinanciereUseCase annulerOperationUseCase;
    private AnnulerClotureCaisseUseCase useCase;

    @BeforeEach
    void setUp() {
        clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        annulerOperationUseCase = mock(AnnulerOperationFinanciereUseCase.class);
        AuteurCourant auteurCourant = mock(AuteurCourant.class);

        when(auteurCourant.nom()).thenReturn("gerant");
        when(clotureCaisseRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        useCase = new AnnulerClotureCaisseUseCase(clotureCaisseRepository,
                periodeClotureeGuard, annulerOperationUseCase, auteurCourant);
    }

    private ClotureCaisse.ClotureCaisseBuilder releve() {
        return ClotureCaisse.builder()
                .id(1L)
                .compteId(2L)
                .dateCloture(JOUR)
                .soldeTheorique(BigDecimal.ZERO)
                .soldeCompte(BigDecimal.ZERO)
                .ecart(BigDecimal.ZERO);
    }

    private void existe(ClotureCaisse cloture) {
        when(clotureCaisseRepository.findById(1L)).thenReturn(Optional.of(cloture));
    }

    @Test
    @DisplayName("Un relevé sans écart se retire, marqué de son motif et de son auteur")
    void releve_sans_ecart_retire() {
        existe(releve().build());

        ClotureCaisse annulee = useCase.executer(1L, "saisi à la mauvaise date");

        assertThat(annulee.estAnnule()).isTrue();
        assertThat(annulee.getMotifAnnulation()).isEqualTo("saisi à la mauvaise date");
        assertThat(annulee.getAnnulePar()).isEqualTo("gerant");
        // Sans écart, aucune écriture n'avait été passée : rien à contre-passer.
        verify(annulerOperationUseCase, never()).execute(anyLong(), anyString());
    }

    @Test
    @DisplayName("L'ajustement d'écart est contre-passé, jamais effacé")
    void ajustement_contre_passe() {
        existe(releve().ecart(BigDecimal.valueOf(-5_000)).operationId(42L).build());

        useCase.executer(1L, "montant mal compté");

        verify(annulerOperationUseCase).execute(anyLong(), anyString());
    }

    @Test
    @DisplayName("Un relevé d'une période close ne se retire pas")
    void periode_close_refusee() {
        existe(releve().build());
        doThrow(new PeriodeClotureeException(JOUR)).when(periodeClotureeGuard).verifier(JOUR);

        assertThatThrownBy(() -> useCase.executer(1L, "erreur"))
                .isInstanceOf(PeriodeClotureeException.class);
        verify(clotureCaisseRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un écart déjà imputé ferme le retrait : il faut extourner d'abord")
    void ecart_impute_refuse() {
        existe(releve().ecart(BigDecimal.valueOf(-5_000))
                .imputationStatut(StatutImputationEcart.PERTE).build());

        assertThatThrownBy(() -> useCase.executer(1L, "erreur"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("extournez");
        verify(clotureCaisseRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un relevé déjà retiré ne se retire pas deux fois")
    void deja_annule_refuse() {
        existe(releve().annuleLe(LocalDateTime.now()).build());

        assertThatThrownBy(() -> useCase.executer(1L, "erreur"))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("Le motif est obligatoire : il justifie le retrait")
    void motif_obligatoire() {
        assertThatThrownBy(() -> useCase.executer(1L, "  "))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
