package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Contre-passation d'un encaissement : le règlement reçu reste un fait, seule
 * sa portée comptable disparaît. On marque donc l'encaissement annulé — avec
 * auteur et motif — et l'on recalcule la ligne depuis la base, qui ne somme que
 * les encaissements actifs.
 */
class AnnulationEncaissementServiceTest {

    private static final Long OPERATION_ID = 500L;

    private EncaissementRepository encaissementRepository;
    private EncaissementCotisationRepository encaissementCotisationRepository;
    private EncaissementPenaliteRepository encaissementPenaliteRepository;
    private LigneRecetteRepository ligneRecetteRepository;
    private LigneCotisationRepository ligneCotisationRepository;
    private LignePenaliteRepository lignePenaliteRepository;
    private AnnulationEncaissementService service;

    @BeforeEach
    void setUp() {
        encaissementRepository = mock(EncaissementRepository.class);
        encaissementCotisationRepository = mock(EncaissementCotisationRepository.class);
        encaissementPenaliteRepository = mock(EncaissementPenaliteRepository.class);
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        lignePenaliteRepository = mock(LignePenaliteRepository.class);

        // Par défaut, aucune des trois tables ne porte d'encaissement lié.
        when(encaissementRepository.findByOperationFinanciereId(anyLong())).thenReturn(Optional.empty());
        when(encaissementCotisationRepository.findByOperationFinanciereId(anyLong())).thenReturn(Optional.empty());
        when(encaissementPenaliteRepository.findByOperationFinanciereId(anyLong())).thenReturn(Optional.empty());

        service = new AnnulationEncaissementService(
                encaissementRepository, encaissementCotisationRepository, encaissementPenaliteRepository,
                ligneRecetteRepository, ligneCotisationRepository, lignePenaliteRepository);
    }

    private OperationFinanciere operation() {
        return OperationFinanciere.builder().id(OPERATION_ID).build();
    }

    private Encaissement encaissementRecette() {
        return Encaissement.builder()
                .id(10L).ligneRecetteId(77L).operationFinanciereId(OPERATION_ID)
                .montant(BigDecimal.valueOf(15_000))
                .build();
    }

    @Test
    @DisplayName("L'encaissement de recette est marqué annulé, jamais supprimé")
    void recette_marquee_annulee() {
        when(encaissementRepository.findByOperationFinanciereId(OPERATION_ID))
                .thenReturn(Optional.of(encaissementRecette()));

        service.annulerEncaissementLie(operation(), "aya", "erreur de saisie");

        ArgumentCaptor<Encaissement> capture = ArgumentCaptor.forClass(Encaissement.class);
        verify(encaissementRepository).save(capture.capture());
        Encaissement annule = capture.getValue();

        assertThat(annule.getAnnuleLe()).isNotNull();
        assertThat(annule.getAnnulePar()).isEqualTo("aya");
        assertThat(annule.getMotifAnnulation()).isEqualTo("erreur de saisie");
        // Le montant reçu reste inscrit : c'est un fait constaté.
        assertThat(annule.getMontant()).isEqualByComparingTo("15000");
        verify(encaissementRepository, never()).deleteById(anyLong());
    }

    @Test
    @DisplayName("La ligne de recette est recalculée depuis la base, pas en mémoire")
    void recette_recalculee_depuis_la_base() {
        when(encaissementRepository.findByOperationFinanciereId(OPERATION_ID))
                .thenReturn(Optional.of(encaissementRecette()));

        service.annulerEncaissementLie(operation(), "aya", "erreur de saisie");

        verify(ligneRecetteRepository).recalculerDepuisEncaissements(77L);
    }

    @Test
    @DisplayName("Un encaissement de cotisation est traité de la même façon")
    void cotisation_annulee() {
        when(encaissementCotisationRepository.findByOperationFinanciereId(OPERATION_ID))
                .thenReturn(Optional.of(EncaissementCotisation.builder()
                        .id(20L).ligneCotisationId(88L).operationFinanciereId(OPERATION_ID).build()));

        service.annulerEncaissementLie(operation(), "aya", "double saisie");

        ArgumentCaptor<EncaissementCotisation> capture =
                ArgumentCaptor.forClass(EncaissementCotisation.class);
        verify(encaissementCotisationRepository).save(capture.capture());
        assertThat(capture.getValue().getAnnuleLe()).isNotNull();
        verify(ligneCotisationRepository).recalculerDepuisEncaissements(88L);
    }

    @Test
    @DisplayName("Un encaissement de pénalité est traité de la même façon")
    void penalite_annulee() {
        when(encaissementPenaliteRepository.findByOperationFinanciereId(OPERATION_ID))
                .thenReturn(Optional.of(EncaissementPenalite.builder()
                        .id(30L).lignePenaliteId(99L).operationFinanciereId(OPERATION_ID).build()));

        service.annulerEncaissementLie(operation(), "aya", "pénalité levée");

        ArgumentCaptor<EncaissementPenalite> capture =
                ArgumentCaptor.forClass(EncaissementPenalite.class);
        verify(encaissementPenaliteRepository).save(capture.capture());
        assertThat(capture.getValue().getAnnuleLe()).isNotNull();
        verify(lignePenaliteRepository).recalculerDepuisEncaissements(99L);
    }

    @Test
    @DisplayName("Un encaissement déjà annulé n'est ni ré-annulé ni recalculé")
    void deja_annule_est_idempotent() {
        Encaissement dejaAnnule = encaissementRecette();
        dejaAnnule.setAnnuleLe(LocalDateTime.of(2026, 4, 1, 9, 0));
        dejaAnnule.setAnnulePar("kouassi");
        when(encaissementRepository.findByOperationFinanciereId(OPERATION_ID))
                .thenReturn(Optional.of(dejaAnnule));

        service.annulerEncaissementLie(operation(), "aya", "seconde tentative");

        verify(encaissementRepository, never()).save(any());
        verify(ligneRecetteRepository, never()).recalculerDepuisEncaissements(anyLong());
        // L'auteur de la première annulation n'est pas écrasé.
        assertThat(dejaAnnule.getAnnulePar()).isEqualTo("kouassi");
    }

    @Test
    @DisplayName("Une opération sans encaissement lié (dépense, maintenance) ne fait rien")
    void operation_sans_encaissement() {
        service.annulerEncaissementLie(operation(), "aya", "annulation dépense");

        verify(encaissementRepository, never()).save(any());
        verifyNoInteractions(ligneRecetteRepository, ligneCotisationRepository, lignePenaliteRepository);
    }

    @Test
    @DisplayName("Une opération nulle ou non persistée est ignorée sans erreur")
    void operation_nulle_ou_sans_id() {
        assertThatCode(() -> service.annulerEncaissementLie(null, "aya", "x"))
                .doesNotThrowAnyException();
        assertThatCode(() -> service.annulerEncaissementLie(
                OperationFinanciere.builder().build(), "aya", "x")).doesNotThrowAnyException();

        verifyNoInteractions(encaissementRepository, encaissementCotisationRepository,
                encaissementPenaliteRepository);
    }
}
