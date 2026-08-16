package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.EncaissementDepasseMontantDuException;
import com.tmk.vtcmanager.application.exception.LigneCotisationDejaSoldeeException;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.NotificationEncaissementService;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Encaissement et annulation d'une cotisation. Le dépôt du chauffeur alimente
 * son compte courant : il doit être plafonné au montant dû, et une ligne qui a
 * reçu de l'argent ne peut plus être annulée telle quelle.
 */
class EncaissementCotisationUseCasesTest {

    private static final Long LIGNE_ID = 88L;
    private static final LocalDate JOUR = LocalDate.of(2026, 4, 10);

    private LigneCotisationRepository ligneCotisationRepository;
    private EncaissementCotisationRepository encaissementCotisationRepository;
    private OperationFinanciereRepository operationFinanciereRepository;
    private CategorieOperationRepository categorieOperationRepository;
    private CompteTresorerieResolver compteTresorerieResolver;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private SequenceReferenceService sequenceReferenceService;
    private CaisseClotureeGuard caisseClotureeGuard;
    private NotificationEncaissementService notificationEncaissementService;
    private CreateEncaissementCotisationUseCase encaisserUseCase;
    private AnnulerLigneCotisationUseCase annulerUseCase;

    @BeforeEach
    void setUp() {
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        encaissementCotisationRepository = mock(EncaissementCotisationRepository.class);
        operationFinanciereRepository = mock(OperationFinanciereRepository.class);
        categorieOperationRepository = mock(CategorieOperationRepository.class);
        compteTresorerieResolver = mock(CompteTresorerieResolver.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        sequenceReferenceService = mock(SequenceReferenceService.class);
        caisseClotureeGuard = mock(CaisseClotureeGuard.class);
        notificationEncaissementService = mock(NotificationEncaissementService.class);

        when(ligneCotisationRepository.findById(LIGNE_ID))
                .thenReturn(Optional.of(ligne(StatutLigneCotisation.EN_ATTENTE, 0)));
        when(ligneCotisationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(encaissementCotisationRepository.save(any())).thenAnswer(inv -> {
            EncaissementCotisation enc = inv.getArgument(0);
            enc.setId(910L);
            return enc;
        });
        when(operationFinanciereRepository.save(any())).thenAnswer(inv -> {
            OperationFinanciere op = inv.getArgument(0);
            op.setId(510L);
            return op;
        });
        when(categorieOperationRepository.findByCode("ENCAISSEMENT_COTISATIONS"))
                .thenReturn(Optional.of(CategorieOperation.builder()
                        .id(4L).code("ENCAISSEMENT_COTISATIONS").build()));
        when(compteTresorerieResolver.resoudre(any(), any())).thenReturn(1L);
        when(sequenceReferenceService.suivante(any())).thenReturn("COT-2026-000007");

        encaisserUseCase = new CreateEncaissementCotisationUseCase(ligneCotisationRepository,
                encaissementCotisationRepository, operationFinanciereRepository,
                categorieOperationRepository, compteTresorerieResolver, periodeClotureeGuard,
                sequenceReferenceService, caisseClotureeGuard, notificationEncaissementService);
        annulerUseCase = new AnnulerLigneCotisationUseCase(ligneCotisationRepository);
    }

    private LigneCotisation ligne(StatutLigneCotisation statut, int encaisse) {
        return LigneCotisation.builder()
                .id(LIGNE_ID).vehiculeId(5L).chauffeurId(1L)
                .dateCotisation(JOUR.minusDays(1)).nomCotisation("Épargne")
                .montantDu(BigDecimal.valueOf(1_000))
                .montantEncaisse(BigDecimal.valueOf(encaisse))
                .statut(statut).encaissements(new ArrayList<>())
                .build();
    }

    private EncaissementCotisation encaissement(int montant, String commentaire) {
        return EncaissementCotisation.builder()
                .montant(BigDecimal.valueOf(montant))
                .modeEncaissement(ModePaiement.ESPECES)
                .dateEncaissement(JOUR).commentaire(commentaire)
                .build();
    }

    @Nested
    @DisplayName("Encaissement")
    class Encaissement {

        @Test
        @DisplayName("Le dépôt est rattaché à sa ligne et à son écriture financière")
        void encaissement_nominal() {
            EncaissementCotisation saved = encaisserUseCase.executer(LIGNE_ID, encaissement(1_000, null));

            assertThat(saved.getId()).isEqualTo(910L);
            assertThat(saved.getLigneCotisationId()).isEqualTo(LIGNE_ID);
            assertThat(saved.getOperationFinanciereId()).isEqualTo(510L);
            verify(ligneCotisationRepository).recalculerDepuisEncaissements(LIGNE_ID);
            verify(notificationEncaissementService).cotisationEncaissee(any(), any());
        }

        @Test
        @DisplayName("L'écriture financière porte la référence du journal des cotisations")
        void ecriture_financiere() {
            encaisserUseCase.executer(LIGNE_ID, encaissement(1_000, null));

            ArgumentCaptor<OperationFinanciere> capture =
                    ArgumentCaptor.forClass(OperationFinanciere.class);
            verify(operationFinanciereRepository).save(capture.capture());
            OperationFinanciere operation = capture.getValue();

            assertThat(operation.getTypeOperation()).isEqualTo(TypeOperation.REVENU);
            assertThat(operation.getStatut()).isEqualTo(StatutOperation.ENCAISSE);
            assertThat(operation.getReference()).isEqualTo("COT-2026-000007");
            assertThat(operation.getDateOperation()).isEqualTo(JOUR);
            assertThat(operation.getDateReference()).isEqualTo(JOUR.minusDays(1));
        }

        @Test
        @DisplayName("Sans commentaire, l'écriture reprend le nom de la cotisation")
        void commentaire_par_defaut() {
            encaisserUseCase.executer(LIGNE_ID, encaissement(1_000, "   "));

            ArgumentCaptor<OperationFinanciere> capture =
                    ArgumentCaptor.forClass(OperationFinanciere.class);
            verify(operationFinanciereRepository).save(capture.capture());
            assertThat(capture.getValue().getCommentaire()).isEqualTo("Épargne");
        }

        @Test
        @DisplayName("Le commentaire saisi est conservé tel quel")
        void commentaire_saisi() {
            encaisserUseCase.executer(LIGNE_ID, encaissement(1_000, "acompte du samedi"));

            ArgumentCaptor<OperationFinanciere> capture =
                    ArgumentCaptor.forClass(OperationFinanciere.class);
            verify(operationFinanciereRepository).save(capture.capture());
            assertThat(capture.getValue().getCommentaire()).isEqualTo("acompte du samedi");
        }

        @Test
        @DisplayName("Un dépôt supérieur au reste dû est refusé")
        void montant_superieur_au_du() {
            when(ligneCotisationRepository.findById(LIGNE_ID))
                    .thenReturn(Optional.of(ligne(StatutLigneCotisation.PARTIELLEMENT_ENCAISSE, 600)));

            assertThatThrownBy(() -> encaisserUseCase.executer(LIGNE_ID, encaissement(500, null)))
                    .isInstanceOf(EncaissementDepasseMontantDuException.class);
            verify(encaissementCotisationRepository, never()).save(any());
        }

        @Test
        @DisplayName("Un dépôt égal au reste dû est accepté")
        void montant_egal_au_restant() {
            when(ligneCotisationRepository.findById(LIGNE_ID))
                    .thenReturn(Optional.of(ligne(StatutLigneCotisation.PARTIELLEMENT_ENCAISSE, 600)));

            assertThatCode(() -> encaisserUseCase.executer(LIGNE_ID, encaissement(400, null)))
                    .doesNotThrowAnyException();
        }

        @Test
        @DisplayName("Une ligne déjà soldée n'accepte plus de dépôt")
        void ligne_soldee() {
            when(ligneCotisationRepository.findById(LIGNE_ID))
                    .thenReturn(Optional.of(ligne(StatutLigneCotisation.ENCAISSE, 1_000)));

            assertThatThrownBy(() -> encaisserUseCase.executer(LIGNE_ID, encaissement(100, null)))
                    .isInstanceOf(LigneCotisationDejaSoldeeException.class);
        }

        @Test
        @DisplayName("Une ligne restituée par un arrêté n'accepte plus de dépôt")
        void ligne_restituee() {
            when(ligneCotisationRepository.findById(LIGNE_ID))
                    .thenReturn(Optional.of(ligne(StatutLigneCotisation.RESTITUEE, 1_000)));

            assertThatThrownBy(() -> encaisserUseCase.executer(LIGNE_ID, encaissement(100, null)))
                    .isInstanceOf(LigneCotisationDejaSoldeeException.class);
        }

        @Test
        @DisplayName("Une ligne inexistante est refusée")
        void ligne_introuvable() {
            when(ligneCotisationRepository.findById(LIGNE_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> encaisserUseCase.executer(LIGNE_ID, encaissement(1_000, null)))
                    .isInstanceOf(LigneCotisationNotFoundException.class);
        }

        @Test
        @DisplayName("Un dépôt dans une période clôturée est refusé")
        void periode_clôturee() {
            doThrow(new PeriodeClotureeException(JOUR)).when(periodeClotureeGuard).verifier(JOUR);

            assertThatThrownBy(() -> encaisserUseCase.executer(LIGNE_ID, encaissement(1_000, null)))
                    .isInstanceOf(PeriodeClotureeException.class);
            verify(encaissementCotisationRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("Annulation")
    class Annulation {

        @Test
        @DisplayName("Une cotisation en attente s'annule avec son motif")
        void annulation_nominale() {
            LigneCotisation annulee = annulerUseCase.executer(LIGNE_ID, "  doublon  ");

            assertThat(annulee.getStatut()).isEqualTo(StatutLigneCotisation.ANNULEE);
            assertThat(annulee.getMotifAnnulation()).isEqualTo("doublon");
            assertThat(annulee.getAnnuleLe()).isNotNull();
        }

        @Test
        @DisplayName("Annuler une ligne déjà annulée ne change rien")
        void annulation_idempotente() {
            when(ligneCotisationRepository.findById(LIGNE_ID))
                    .thenReturn(Optional.of(ligne(StatutLigneCotisation.ANNULEE, 0)));

            annulerUseCase.executer(LIGNE_ID, "autre motif");

            verify(ligneCotisationRepository, never()).save(any());
        }

        @Test
        @DisplayName("Un motif vide est refusé")
        void motif_obligatoire() {
            assertThatThrownBy(() -> annulerUseCase.executer(LIGNE_ID, "  "))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("Une cotisation déjà versée ne s'annule pas directement")
        void avec_versement() {
            when(ligneCotisationRepository.findById(LIGNE_ID))
                    .thenReturn(Optional.of(ligne(StatutLigneCotisation.PARTIELLEMENT_ENCAISSE, 400)));

            assertThatThrownBy(() -> annulerUseCase.executer(LIGNE_ID, "erreur"))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("Annulez d'abord les encaissements");
        }

        @Test
        @DisplayName("Une ligne inexistante est refusée")
        void ligne_introuvable() {
            when(ligneCotisationRepository.findById(LIGNE_ID)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> annulerUseCase.executer(LIGNE_ID, "erreur"))
                    .isInstanceOf(LigneCotisationNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Reste dû")
    class MontantRestant {

        @Test
        @DisplayName("Le reste dû est la différence entre montant dû et encaissé")
        void reste_du() {
            assertThat(ligne(StatutLigneCotisation.PARTIELLEMENT_ENCAISSE, 400).montantRestant())
                    .isEqualByComparingTo("600");
        }

        @Test
        @DisplayName("Un trop-perçu ne rend jamais un reste dû négatif")
        void jamais_negatif() {
            assertThat(ligne(StatutLigneCotisation.ENCAISSE, 1_500).montantRestant())
                    .isEqualByComparingTo("0");
        }

        @Test
        @DisplayName("Sans encaissement, le reste dû vaut le montant dû")
        void sans_encaissement() {
            LigneCotisation ligne = ligne(StatutLigneCotisation.EN_ATTENTE, 0);
            ligne.setMontantEncaisse(null);

            assertThat(ligne.montantRestant()).isEqualByComparingTo("1000");
        }
    }
}
