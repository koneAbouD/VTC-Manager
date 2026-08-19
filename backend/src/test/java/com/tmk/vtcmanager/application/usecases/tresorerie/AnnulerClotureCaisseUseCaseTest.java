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
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
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

        // Le retour sur imputation n'est pas simulé : c'est la cascade réelle
        // qu'on veut voir jouer quand un écart tranché doit être défait.
        useCase = new AnnulerClotureCaisseUseCase(clotureCaisseRepository,
                periodeClotureeGuard, annulerOperationUseCase,
                new AnnulerImputationEcartUseCase(clotureCaisseRepository, periodeClotureeGuard,
                        annulerOperationUseCase),
                auteurCourant);
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
        verify(annulerOperationUseCase, never()).execute(anyLong(), anyString(), any());
    }

    @Test
    @DisplayName("L'ajustement d'écart est contre-passé à la date du relevé, jamais effacé")
    void ajustement_contre_passe() {
        existe(releve().ecart(BigDecimal.valueOf(-5_000)).operationId(42L).build());

        useCase.executer(1L, "montant mal compté");

        // La date de l'extourne est celle du relevé, pas celle du jour : c'est
        // la journée comptée qu'il s'agit de remettre dans son état d'avant.
        // Extournée au jour de l'annulation, elle laisserait le solde théorique
        // de cette journée faussé du montant de l'écart — et le recomptage
        // buterait sur un écart que plus rien ne justifie.
        verify(annulerOperationUseCase).execute(eq(42L), anyString(), eq(JOUR));
    }

    @Test
    @DisplayName("L'écart cesse d'attendre une imputation : il n'a plus d'existence")
    void imputation_en_attente_effacee() {
        existe(releve().ecart(BigDecimal.valueOf(-5_000)).operationId(42L)
                .imputationStatut(StatutImputationEcart.EN_ATTENTE).build());

        ClotureCaisse annulee = useCase.executer(1L, "montant mal compté");

        // Le laisser EN_ATTENTE ferait figurer un arbitrage fantôme dans tout
        // état des écarts à trancher, alors que l'ajustement est contre-passé.
        assertThat(annulee.attendImputation()).isFalse();
        assertThat(annulee.getImputationStatut()).isNull();
    }

    @Test
    @DisplayName("Un compte recompté depuis se défait par le relevé le plus récent")
    void recompte_depuis_refuse() {
        existe(releve().build());
        when(clotureCaisseRepository.findDerniereDateCloture(2L))
                .thenReturn(Optional.of(JOUR.plusDays(3)));

        // Le comptage postérieur a été fait sur un solde théorique où
        // l'ajustement de celui-ci était déjà compris : retirer l'ancien
        // d'abord rendrait le récent faux sans que personne ne l'ait touché.
        assertThatThrownBy(() -> useCase.executer(1L, "erreur"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("recompté depuis");
        verify(clotureCaisseRepository, never()).save(any());
    }

    @Test
    @DisplayName("Le dernier relevé du compte se retire sans obstacle")
    void dernier_releve_retire() {
        existe(releve().build());
        when(clotureCaisseRepository.findDerniereDateCloture(2L)).thenReturn(Optional.of(JOUR));

        assertThat(useCase.executer(1L, "erreur").estAnnule()).isTrue();
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
    @DisplayName("Un écart déjà imputé est défait avec le relevé, pas opposé à son retrait")
    void ecart_impute_defait_en_cascade() {
        existe(releve().ecart(BigDecimal.valueOf(-5_000)).operationId(42L)
                .imputationStatut(StatutImputationEcart.PERTE)
                .operationSoldeAttenteId(50L)
                .operationImputationId(51L)
                .build());

        ClotureCaisse annulee = useCase.executer(1L, "montant mal compté");

        // Exiger de l'utilisateur qu'il extourne d'abord l'enfermait : l'action
        // n'existait nulle part, et une extourne passée à la main n'aurait pas
        // remis l'écart en attente — le retrait serait resté refusé pour
        // toujours.
        assertThat(annulee.estAnnule()).isTrue();
        // Les trois écritures tombent à la date du relevé : c'est cette
        // journée-là qu'il s'agit de remettre dans son état d'avant.
        verify(annulerOperationUseCase).execute(eq(50L), anyString(), eq(JOUR));
        verify(annulerOperationUseCase).execute(eq(51L), anyString(), eq(JOUR));
        verify(annulerOperationUseCase).execute(eq(42L), anyString(), eq(JOUR));
        // Plus personne n'a à trancher un écart qui n'existe plus.
        assertThat(annulee.getImputationStatut()).isNull();
        assertThat(annulee.getOperationImputationId()).isNull();
        assertThat(annulee.getOperationSoldeAttenteId()).isNull();
    }

    @Test
    @DisplayName("Un recouvrement n'a produit qu'une écriture : elle seule est contre-passée")
    void ecart_recouvre_defait_une_seule_ecriture() {
        existe(releve().ecart(BigDecimal.valueOf(-5_000)).operationId(42L)
                .imputationStatut(StatutImputationEcart.RECOUVREE)
                .operationSoldeAttenteId(50L)
                .build());

        useCase.executer(1L, "montant mal compté");

        verify(annulerOperationUseCase).execute(eq(50L), anyString(), eq(JOUR));
        verify(annulerOperationUseCase).execute(eq(42L), anyString(), eq(JOUR));
        verify(annulerOperationUseCase, times(2)).execute(anyLong(), anyString(), any());
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
