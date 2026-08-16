package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.ModeEncaissement;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.CaisseClotureeException;
import com.tmk.vtcmanager.application.exception.EncaissementDepasseMontantAttenduException;
import com.tmk.vtcmanager.application.exception.LigneRecetteDejaSoldeeException;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.exception.ModePaiementNonAutoriseException;
import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.NotificationEncaissementService;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Encaissement d'une recette. Le use case porte les contrôles qui protègent la
 * caisse : mode de paiement conforme à la condition du véhicule, montant
 * plafonné au reste dû, et refus d'écrire dans une période ou une journée déjà
 * arrêtée. Il crée en outre l'écriture financière qui portera l'encaissement
 * en comptabilité.
 */
class CreateEncaissementUseCaseTest {

    private static final Long LIGNE_ID = 77L;
    private static final LocalDate JOUR = LocalDate.of(2026, 4, 10);

    private LigneRecetteRepository ligneRecetteRepository;
    private EncaissementRepository encaissementRepository;
    private ConfigurationRecetteRepository configurationRecetteRepository;
    private OperationFinanciereRepository operationFinanciereRepository;
    private CategorieOperationRepository categorieOperationRepository;
    private CompteTresorerieResolver compteTresorerieResolver;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private SequenceReferenceService sequenceReferenceService;
    private CaisseClotureeGuard caisseClotureeGuard;
    private NotificationEncaissementService notificationEncaissementService;
    private CreateEncaissementUseCase useCase;

    @BeforeEach
    void setUp() {
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        encaissementRepository = mock(EncaissementRepository.class);
        configurationRecetteRepository = mock(ConfigurationRecetteRepository.class);
        operationFinanciereRepository = mock(OperationFinanciereRepository.class);
        categorieOperationRepository = mock(CategorieOperationRepository.class);
        compteTresorerieResolver = mock(CompteTresorerieResolver.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        sequenceReferenceService = mock(SequenceReferenceService.class);
        caisseClotureeGuard = mock(CaisseClotureeGuard.class);
        notificationEncaissementService = mock(NotificationEncaissementService.class);

        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne(0)));
        when(encaissementRepository.save(any())).thenAnswer(inv -> {
            Encaissement enc = inv.getArgument(0);
            enc.setId(900L);
            return enc;
        });
        when(operationFinanciereRepository.save(any())).thenAnswer(inv -> {
            OperationFinanciere op = inv.getArgument(0);
            op.setId(500L);
            return op;
        });
        when(categorieOperationRepository.findByCode("ENCAISSEMENT_RECETTES"))
                .thenReturn(Optional.of(CategorieOperation.builder()
                        .id(3L).code("ENCAISSEMENT_RECETTES").build()));
        when(compteTresorerieResolver.resoudre(any(), any())).thenReturn(1L);
        when(sequenceReferenceService.suivante(any())).thenReturn("ENC-2026-000042");
        when(configurationRecetteRepository.findByVehiculeId(anyLong())).thenReturn(Optional.empty());

        useCase = new CreateEncaissementUseCase(ligneRecetteRepository, encaissementRepository,
                configurationRecetteRepository, operationFinanciereRepository,
                categorieOperationRepository, compteTresorerieResolver, periodeClotureeGuard,
                sequenceReferenceService, caisseClotureeGuard, notificationEncaissementService);
    }

    private LigneRecette ligne(int dejaEncaisse) {
        return LigneRecette.builder()
                .id(LIGNE_ID).vehiculeId(5L).chauffeurId(1L).dateRecette(JOUR.minusDays(1))
                .montantAttendu(BigDecimal.valueOf(15_000))
                .montantEncaisse(BigDecimal.valueOf(dejaEncaisse))
                .statut(dejaEncaisse > 0
                        ? StatutLigneRecette.PARTIELLEMENT_ENCAISSE : StatutLigneRecette.EN_ATTENTE)
                .encaissements(new ArrayList<>())
                .build();
    }

    private Encaissement encaissement(int montant, ModePaiement mode) {
        return Encaissement.builder()
                .montant(BigDecimal.valueOf(montant)).modeEncaissement(mode)
                .dateEncaissement(JOUR).commentaire("versement du soir")
                .build();
    }

    private void configuration(ModeEncaissement mode) {
        when(configurationRecetteRepository.findByVehiculeId(5L))
                .thenReturn(Optional.of(ConfigurationRecette.builder()
                        .id(1L).vehiculeId(5L).modeEncaissement(mode)
                        .cotisations(new ArrayList<>()).build()));
    }

    // ── Cas nominal ─────────────────────────────────────────────────────────

    @Test
    @DisplayName("L'encaissement est rattaché à sa ligne et enregistré")
    void encaissement_enregistre() {
        Encaissement saved = useCase.executer(LIGNE_ID, encaissement(15_000, ModePaiement.ESPECES));

        assertThat(saved.getId()).isEqualTo(900L);
        assertThat(saved.getLigneRecetteId()).isEqualTo(LIGNE_ID);
        assertThat(saved.getOperationFinanciereId()).isEqualTo(500L);
    }

    @Test
    @DisplayName("Une écriture financière de revenu est créée avec sa référence de journal")
    void ecriture_financiere_creee() {
        useCase.executer(LIGNE_ID, encaissement(15_000, ModePaiement.ESPECES));

        ArgumentCaptor<OperationFinanciere> capture =
                ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository).save(capture.capture());
        OperationFinanciere operation = capture.getValue();

        assertThat(operation.getTypeOperation()).isEqualTo(TypeOperation.REVENU);
        assertThat(operation.getStatut()).isEqualTo(StatutOperation.ENCAISSE);
        assertThat(operation.getReference()).isEqualTo("ENC-2026-000042");
        assertThat(operation.getMontant()).isEqualByComparingTo("15000");
        assertThat(operation.getCategorie().getCode()).isEqualTo("ENCAISSEMENT_RECETTES");
        assertThat(operation.getVehicule().getId()).isEqualTo(5L);
        assertThat(operation.getChauffeur().getId()).isEqualTo(1L);
        assertThat(operation.getCompteTresorerieId()).isEqualTo(1L);
    }

    @Test
    @DisplayName("L'écriture porte deux dates : le jour du versement et le jour de la recette due")
    void deux_dates_distinctes() {
        useCase.executer(LIGNE_ID, encaissement(15_000, ModePaiement.ESPECES));

        ArgumentCaptor<OperationFinanciere> capture =
                ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository).save(capture.capture());

        // Un versement du 10 pour la recette du 9 : la trésorerie bouge le 10,
        // mais la recette reste rattachée à la journée d'exploitation du 9.
        assertThat(capture.getValue().getDateOperation()).isEqualTo(JOUR);
        assertThat(capture.getValue().getDateReference()).isEqualTo(JOUR.minusDays(1));
    }

    @Test
    @DisplayName("La ligne est recalculée depuis la base, puis seulement notifiée")
    void recalcul_puis_notification() {
        useCase.executer(LIGNE_ID, encaissement(15_000, ModePaiement.ESPECES));

        // L'ordre importe : la notification ne doit annoncer que ce qui est
        // effectivement enregistré.
        InOrder ordre = inOrder(ligneRecetteRepository, notificationEncaissementService);
        ordre.verify(ligneRecetteRepository).recalculerDepuisEncaissements(LIGNE_ID);
        ordre.verify(notificationEncaissementService).recetteEncaissee(any(), any());
    }

    // ── Contrôles ───────────────────────────────────────────────────────────

    @Test
    @DisplayName("Une ligne inexistante est refusée")
    void ligne_introuvable() {
        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, encaissement(15_000, ModePaiement.ESPECES)))
                .isInstanceOf(LigneRecetteNotFoundException.class);
    }

    @Test
    @DisplayName("Une ligne déjà soldée ou annulée n'accepte plus de versement")
    void ligne_deja_soldee() {
        LigneRecette soldee = ligne(15_000);
        soldee.setStatut(StatutLigneRecette.ENCAISSE);
        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(soldee));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, encaissement(1_000, ModePaiement.ESPECES)))
                .isInstanceOf(LigneRecetteDejaSoldeeException.class);
        verify(encaissementRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un versement dans une période clôturée est refusé")
    void periode_clôturee() {
        doThrow(new PeriodeClotureeException(JOUR)).when(periodeClotureeGuard).verifier(JOUR);

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, encaissement(15_000, ModePaiement.ESPECES)))
                .isInstanceOf(PeriodeClotureeException.class);
        verify(encaissementRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un versement sur une caisse déjà comptée ce jour-là est refusé")
    void caisse_clôturee() {
        doThrow(new CaisseClotureeException(JOUR, JOUR)).when(caisseClotureeGuard).verifier(1L, JOUR);

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, encaissement(15_000, ModePaiement.ESPECES)))
                .isInstanceOf(CaisseClotureeException.class);
        verify(encaissementRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un véhicule en espèces seules refuse le mobile money")
    void mode_paiement_non_autorise() {
        configuration(ModeEncaissement.ESPECES);

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID,
                encaissement(15_000, ModePaiement.MOBILE_MONEY)))
                .isInstanceOf(ModePaiementNonAutoriseException.class);
    }

    @Test
    @DisplayName("Un véhicule en mobile money seul refuse les espèces")
    void mode_especes_non_autorise() {
        configuration(ModeEncaissement.MOBILE_MONEY);

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID,
                encaissement(15_000, ModePaiement.ESPECES)))
                .isInstanceOf(ModePaiementNonAutoriseException.class);
    }

    @Test
    @DisplayName("Un véhicule ouvert aux deux canaux accepte l'un comme l'autre")
    void les_deux_modes_autorises() {
        configuration(ModeEncaissement.LES_DEUX);

        assertThatCode(() -> useCase.executer(LIGNE_ID,
                encaissement(15_000, ModePaiement.MOBILE_MONEY))).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Sans configuration de recette, aucun mode n'est refusé")
    void sans_configuration_aucun_controle() {
        assertThatCode(() -> useCase.executer(LIGNE_ID,
                encaissement(15_000, ModePaiement.MOBILE_MONEY))).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Un versement supérieur au reste dû est refusé")
    void montant_superieur_au_restant() {
        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne(10_000)));

        // Reste dû : 5 000. Un versement de 6 000 déborderait.
        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, encaissement(6_000, ModePaiement.ESPECES)))
                .isInstanceOf(EncaissementDepasseMontantAttenduException.class);
    }

    @Test
    @DisplayName("Un versement égal au reste dû solde la ligne")
    void montant_egal_au_restant() {
        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne(10_000)));

        assertThatCode(() -> useCase.executer(LIGNE_ID, encaissement(5_000, ModePaiement.ESPECES)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("En recette réelle, aucun plafond ne s'applique")
    void montant_reel_sans_plafond() {
        LigneRecette reelle = ligne(0);
        reelle.setMontantAttendu(null);
        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(reelle));

        assertThatCode(() -> useCase.executer(LIGNE_ID, encaissement(50_000, ModePaiement.ESPECES)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Une catégorie comptable absente n'empêche pas l'encaissement")
    void categorie_absente() {
        when(categorieOperationRepository.findByCode("ENCAISSEMENT_RECETTES"))
                .thenReturn(Optional.empty());

        assertThatCode(() -> useCase.executer(LIGNE_ID, encaissement(15_000, ModePaiement.ESPECES)))
                .doesNotThrowAnyException();
    }
}
