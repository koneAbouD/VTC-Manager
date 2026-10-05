package com.tmk.vtcmanager.application.usecases.montant;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.modification.ModificationMontant;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModificationMontantRepository;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.ModificationMontantService;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import com.tmk.vtcmanager.application.usecases.penalite.ModifierMontantPenaliteUseCase;
import com.tmk.vtcmanager.application.usecases.recette.ModifierMontantAttenduRecetteUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Corriger ce qu'un chauffeur doit : le montant change, les versements non,
 * et la correction laisse une trace. Refusée dès qu'un document a figé le
 * montant ou qu'elle ferait de l'argent déjà versé un trop-perçu.
 */
class ModifierMontantUseCaseTest {

    private static final LocalDate JOUR = LocalDate.of(2026, 9, 10);

    private LigneRecetteRepository ligneRecetteRepository;
    private LignePenaliteRepository lignePenaliteRepository;
    private ArreteCompteRepository arreteCompteRepository;
    private PaiementRepository paiementRepository;
    private VerrouArreteService verrouArreteService;
    private ModificationMontantRepository journal;
    private ModifierMontantAttenduRecetteUseCase recetteUseCase;
    private ModifierMontantPenaliteUseCase penaliteUseCase;

    @BeforeEach
    void setUp() {
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        arreteCompteRepository = mock(ArreteCompteRepository.class);
        paiementRepository = mock(PaiementRepository.class);
        verrouArreteService = mock(VerrouArreteService.class);
        journal = mock(ModificationMontantRepository.class);
        AuteurCourant auteur = () -> "gestionnaire";
        when(verrouArreteService.verrous()).thenReturn(new VerrouArreteService.Verrous(null, null, Map.of()));

        ModificationMontantService service = new ModificationMontantService(
                verrouArreteService, arreteCompteRepository, paiementRepository);
        recetteUseCase = new ModifierMontantAttenduRecetteUseCase(ligneRecetteRepository,
                arreteCompteRepository, journal, service, auteur);
        penaliteUseCase = new ModifierMontantPenaliteUseCase(lignePenaliteRepository,
                arreteCompteRepository, journal, service, auteur);
    }

    private LigneRecette recette(String attendu, String encaisse, StatutLigneRecette statut) {
        LigneRecette l = LigneRecette.builder().id(1L).dateRecette(JOUR)
                .montantAttendu(attendu == null ? null : new BigDecimal(attendu))
                .montantEncaisse(new BigDecimal(encaisse)).statut(statut).build();
        when(ligneRecetteRepository.findById(1L)).thenReturn(Optional.of(l));
        return l;
    }

    private LignePenalite penalite(TypeSanction sanction, String montant, String encaisse) {
        LignePenalite p = LignePenalite.builder().id(2L).dateFaute(JOUR).typeSanction(sanction)
                .montant(new BigDecimal(montant)).montantEncaisse(new BigDecimal(encaisse))
                .statut(StatutLignePenalite.PARTIELLEMENT_ENCAISSEE).build();
        when(lignePenaliteRepository.findById(2L)).thenReturn(Optional.of(p));
        return p;
    }

    @Test
    @DisplayName("Recette : le montant change, le statut se relit, la correction est consignée")
    void recette_modifiee_et_journalisee() {
        recette("15000", "10000", StatutLigneRecette.PARTIELLEMENT_ENCAISSE);

        recetteUseCase.executer(1L, new BigDecimal("12000"), "  Tarif négocié  ");

        verify(arreteCompteRepository).verrouillerExecution();
        verify(ligneRecetteRepository).modifierMontantAttendu(1L, new BigDecimal("12000"));
        verify(ligneRecetteRepository).recalculerDepuisEncaissements(1L);
        ArgumentCaptor<ModificationMontant> trace = ArgumentCaptor.forClass(ModificationMontant.class);
        verify(journal).enregistrer(trace.capture());
        assertThat(trace.getValue().document()).isEqualTo(TypeDocumentCreance.RECETTE);
        assertThat(trace.getValue().ancienMontant()).isEqualByComparingTo("15000");
        assertThat(trace.getValue().nouveauMontant()).isEqualByComparingTo("12000");
        assertThat(trace.getValue().motif()).isEqualTo("Tarif négocié");
        assertThat(trace.getValue().createdBy()).isEqualTo("gestionnaire");
    }

    @Test
    @DisplayName("Recette : impossible de descendre sous ce qui a déjà été versé")
    void recette_sous_le_verse_refusee() {
        recette("15000", "10000", StatutLigneRecette.PARTIELLEMENT_ENCAISSE);

        assertThatThrownBy(() -> recetteUseCase.executer(1L, new BigDecimal("8000"), "erreur"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("déjà été versé");
        verify(ligneRecetteRepository, never()).modifierMontantAttendu(anyLong(), any());
    }

    @Test
    @DisplayName("Recette : refusée une fois compensée par un arrêté")
    void recette_compensee_par_arrete_refusee() {
        recette("15000", "0", StatutLigneRecette.EN_ATTENTE);
        when(arreteCompteRepository.existeLigneValidePourDocument(TypeDocumentCreance.RECETTE, 1L))
                .thenReturn(true);

        assertThatThrownBy(() -> recetteUseCase.executer(1L, new BigDecimal("12000"), "erreur"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("arrêté");
        verify(journal, never()).enregistrer(any());
    }

    @Test
    @DisplayName("Recette : refusée au montant réel, annulée, ou avec un paiement en vol")
    void recette_refus_divers() {
        recette(null, "0", StatutLigneRecette.EN_ATTENTE);
        assertThatThrownBy(() -> recetteUseCase.executer(1L, new BigDecimal("12000"), "x"))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("montant réel");

        recette("15000", "0", StatutLigneRecette.ANNULEE);
        assertThatThrownBy(() -> recetteUseCase.executer(1L, new BigDecimal("12000"), "x"))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("annulée");

        recette("15000", "0", StatutLigneRecette.EN_ATTENTE);
        when(paiementRepository.existeEnCours(TypeCiblePaiement.RECETTE, 1L)).thenReturn(true);
        assertThatThrownBy(() -> recetteUseCase.executer(1L, new BigDecimal("12000"), "x"))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("mobile money");
    }

    @Test
    @DisplayName("Recette : période close, le montant ne bouge plus")
    void recette_periode_close_refusee() {
        recette("15000", "0", StatutLigneRecette.EN_ATTENTE);
        when(verrouArreteService.verrous()).thenReturn(
                new VerrouArreteService.Verrous(JOUR.plusDays(20), null, Map.of()));

        assertThatThrownBy(() -> recetteUseCase.executer(1L, new BigDecimal("12000"), "x"))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("clôturée");
    }

    @Test
    @DisplayName("Recette : une caisse comptée ne fige pas le montant, seule la période close le fait")
    void recette_caisse_comptee_autorisee() {
        recette("15000", "0", StatutLigneRecette.EN_ATTENTE);
        when(verrouArreteService.verrous()).thenReturn(
                new VerrouArreteService.Verrous(null, JOUR.plusDays(5), Map.of()));

        recetteUseCase.executer(1L, new BigDecimal("12000"), "tarif");

        verify(ligneRecetteRepository).modifierMontantAttendu(1L, new BigDecimal("12000"));
    }

    @Test
    @DisplayName("Motif obligatoire, et un montant identique ne fait rien")
    void motif_obligatoire_et_identique_sans_effet() {
        recette("15000", "0", StatutLigneRecette.EN_ATTENTE);
        assertThatThrownBy(() -> recetteUseCase.executer(1L, new BigDecimal("12000"), " "))
                .isInstanceOf(IllegalArgumentException.class);

        recetteUseCase.executer(1L, new BigDecimal("15000.00"), "rien");
        verify(ligneRecetteRepository, never()).modifierMontantAttendu(anyLong(), any());
        verify(journal, never()).enregistrer(any());
    }

    @Test
    @DisplayName("Amende : montant corrigé et consigné ; une autre sanction n'a pas de montant")
    void penalite() {
        penalite(TypeSanction.AMENDE, "5000", "2000");
        penaliteUseCase.executer(2L, new BigDecimal("3000"), "barème");
        verify(lignePenaliteRepository).modifierMontant(2L, new BigDecimal("3000"));
        verify(lignePenaliteRepository).recalculerDepuisEncaissements(2L);
        verify(journal).enregistrer(any());

        penalite(TypeSanction.BUZZER, "0", "0");
        assertThatThrownBy(() -> penaliteUseCase.executer(2L, new BigDecimal("3000"), "x"))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("amende");
    }
}
