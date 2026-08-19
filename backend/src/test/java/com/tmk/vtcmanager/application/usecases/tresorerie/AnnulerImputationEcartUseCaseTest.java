package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
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
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Retour sur une imputation d'écart de caisse.
 *
 * <p>La décision se prend souvent avant d'avoir tout compris : le manquant du
 * mardi s'explique le jeudi par une recette saisie deux fois. Il faut donc
 * pouvoir la défaire — sans quoi le relevé lui-même devenait irretirable.
 */
class AnnulerImputationEcartUseCaseTest {

    private static final LocalDate JOUR = LocalDate.of(2026, 8, 3);

    private ClotureCaisseRepository clotureCaisseRepository;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private AnnulerOperationFinanciereUseCase annulerOperationUseCase;
    private AnnulerImputationEcartUseCase useCase;

    @BeforeEach
    void setUp() {
        clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        annulerOperationUseCase = mock(AnnulerOperationFinanciereUseCase.class);

        when(clotureCaisseRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        useCase = new AnnulerImputationEcartUseCase(clotureCaisseRepository,
                periodeClotureeGuard, annulerOperationUseCase);
    }

    private ClotureCaisse.ClotureCaisseBuilder releveImpute(StatutImputationEcart decision) {
        return ClotureCaisse.builder()
                .id(1L)
                .compteId(2L)
                .dateCloture(JOUR)
                .ecart(BigDecimal.valueOf(500))
                .imputationStatut(decision)
                .imputationMotif("erreur de comptage")
                .imputeeLe(LocalDateTime.now())
                .imputeePar("gerant")
                .operationSoldeAttenteId(50L);
    }

    private void existe(ClotureCaisse cloture) {
        when(clotureCaisseRepository.findById(1L)).thenReturn(Optional.of(cloture));
    }

    @Test
    @DisplayName("Une perte imputée se défait : les deux écritures sont contre-passées")
    void perte_defaite() {
        existe(releveImpute(StatutImputationEcart.PERTE).operationImputationId(51L).build());

        ClotureCaisse resultat = useCase.executer(1L, "le manquant s'explique");

        // À la date du relevé, comme elles avaient été passées : les extourner
        // au jour de la décision les ferait tomber dans un autre mois que les
        // écritures qu'elles neutralisent.
        verify(annulerOperationUseCase).execute(eq(50L), anyString(), eq(JOUR));
        verify(annulerOperationUseCase).execute(eq(51L), anyString(), eq(JOUR));
        assertThat(resultat.attendImputation()).isTrue();
    }

    @Test
    @DisplayName("L'écart redevient à trancher, sans trace d'un arbitrage périmé")
    void decision_effacee() {
        existe(releveImpute(StatutImputationEcart.PERTE).operationImputationId(51L).build());

        ClotureCaisse resultat = useCase.executer(1L, "le manquant s'explique");

        assertThat(resultat.getImputationStatut()).isEqualTo(StatutImputationEcart.EN_ATTENTE);
        assertThat(resultat.getImputationMotif()).isNull();
        assertThat(resultat.getImputeeLe()).isNull();
        assertThat(resultat.getImputeePar()).isNull();
        assertThat(resultat.getOperationImputationId()).isNull();
        assertThat(resultat.getOperationSoldeAttenteId()).isNull();
    }

    @Test
    @DisplayName("Un recouvrement n'avait produit qu'une écriture : rien de plus à défaire")
    void recouvrement_defait_une_seule_ecriture() {
        existe(releveImpute(StatutImputationEcart.RECOUVREE).build());

        useCase.executer(1L, "le caissier a rendu l'argent par erreur");

        verify(annulerOperationUseCase).execute(eq(50L), anyString(), eq(JOUR));
        verify(annulerOperationUseCase, times(1)).execute(anyLong(), anyString(), any());
    }

    @Test
    @DisplayName("Une imputation d'avant le rattachement se défait quand même")
    void ecriture_attente_inconnue_ne_bloque_pas() {
        existe(releveImpute(StatutImputationEcart.PERTE)
                .operationSoldeAttenteId(null).operationImputationId(51L).build());

        // Bloquer ici enfermerait de nouveau l'utilisateur : l'écriture reste au
        // journal, orpheline, et se contre-passe à la main.
        ClotureCaisse resultat = useCase.executer(1L, "décision revue");

        verify(annulerOperationUseCase).execute(eq(51L), anyString(), eq(JOUR));
        assertThat(resultat.attendImputation()).isTrue();
    }

    @Test
    @DisplayName("Un écart resté en attente n'a rien à défaire")
    void ecart_non_impute_refuse() {
        existe(releveImpute(StatutImputationEcart.EN_ATTENTE).build());

        assertThatThrownBy(() -> useCase.executer(1L, "décision revue"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("n'a pas été imputé");
        verify(clotureCaisseRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une période close fige la décision : les états ont été publiés avec elle")
    void periode_close_refusee() {
        existe(releveImpute(StatutImputationEcart.PERTE).operationImputationId(51L).build());
        doThrow(new PeriodeClotureeException(JOUR)).when(periodeClotureeGuard).verifier(JOUR);

        assertThatThrownBy(() -> useCase.executer(1L, "décision revue"))
                .isInstanceOf(PeriodeClotureeException.class);
        verify(annulerOperationUseCase, never()).execute(anyLong(), anyString(), any());
        verify(clotureCaisseRepository, never()).save(any());
    }

    @Test
    @DisplayName("Le motif est obligatoire : il justifie le retour sur la décision")
    void motif_obligatoire() {
        assertThatThrownBy(() -> useCase.executer(1L, " "))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
