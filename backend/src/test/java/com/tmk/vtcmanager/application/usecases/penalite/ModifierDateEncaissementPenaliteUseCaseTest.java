package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.exception.EncaissementFuturException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.EncaissementFuturGuard;
import com.tmk.vtcmanager.application.services.ModificationDateEncaissementService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Correction de la date d'un versement d'amende.
 *
 * <p>Même mécanique que pour une recette : le versement et son écriture partent
 * ensemble à la nouvelle date, et la date de référence — le jour de la faute —
 * ne suit pas. Seules les amendes encaissent : les autres sanctions n'ont aucun
 * versement à redater.
 */
class ModifierDateEncaissementPenaliteUseCaseTest {

    private static final Long LIGNE_ID = 33L;
    private static final Long ENCAISSEMENT_ID = 6L;
    private static final Long OPERATION_ID = 500L;
    private static final Long CAISSE = 1L;
    private static final LocalDate JOUR_FAUTE = LocalDate.of(2026, 4, 7);
    private static final LocalDate SAISIE_LE = LocalDate.of(2026, 4, 10);
    private static final LocalDate REELLEMENT_LE = LocalDate.of(2026, 4, 8);

    private LignePenaliteRepository lignePenaliteRepository;
    private EncaissementPenaliteRepository encaissementRepository;
    private OperationFinanciereRepository operationFinanciereRepository;
    private ModificationDateEncaissementService modificationDateService;
    private ModifierDateEncaissementPenaliteUseCase useCase;

    @BeforeEach
    void setUp() {
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        encaissementRepository = mock(EncaissementPenaliteRepository.class);
        operationFinanciereRepository = mock(OperationFinanciereRepository.class);
        modificationDateService = mock(ModificationDateEncaissementService.class);

        when(lignePenaliteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne()));
        when(encaissementRepository.findById(ENCAISSEMENT_ID))
                .thenReturn(Optional.of(encaissement()));
        when(operationFinanciereRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(operation()));

        useCase = new ModifierDateEncaissementPenaliteUseCase(lignePenaliteRepository,
                encaissementRepository, operationFinanciereRepository, modificationDateService,
                new EncaissementFuturGuard());
    }

    private LignePenalite ligne() {
        return LignePenalite.builder()
                .id(LIGNE_ID)
                .vehiculeId(1L).chauffeurId(2L)
                .typeSanction(TypeSanction.AMENDE)
                .dateFaute(JOUR_FAUTE)
                .montant(new BigDecimal("5000"))
                .montantEncaisse(new BigDecimal("5000"))
                .statut(StatutLignePenalite.ENCAISSEE)
                .encaissements(List.of(encaissement()))
                .build();
    }

    private EncaissementPenalite encaissement() {
        return EncaissementPenalite.builder()
                .id(ENCAISSEMENT_ID)
                .lignePenaliteId(LIGNE_ID)
                .operationFinanciereId(OPERATION_ID)
                .montant(new BigDecimal("5000"))
                .modeEncaissement(ModePaiement.ESPECES)
                .dateEncaissement(SAISIE_LE)
                .build();
    }

    private OperationFinanciere operation() {
        return OperationFinanciere.builder()
                .id(OPERATION_ID)
                .montant(new BigDecimal("5000"))
                .compteTresorerieId(CAISSE)
                .dateOperation(SAISIE_LE)
                .dateReference(JOUR_FAUTE)
                .statut(StatutOperation.ENCAISSE)
                .build();
    }

    @Test
    @DisplayName("Le versement et son écriture partent à la même nouvelle date")
    void deplace_les_deux() {
        useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE);

        ArgumentCaptor<EncaissementPenalite> versement =
                ArgumentCaptor.forClass(EncaissementPenalite.class);
        verify(encaissementRepository).save(versement.capture());
        assertThat(versement.getValue().getDateEncaissement()).isEqualTo(REELLEMENT_LE);
        assertThat(versement.getValue().getMontant()).isEqualByComparingTo("5000");

        ArgumentCaptor<OperationFinanciere> ecriture =
                ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository).save(ecriture.capture());
        assertThat(ecriture.getValue().getDateOperation()).isEqualTo(REELLEMENT_LE);
        // La date de référence est le jour sanctionné, pas celui du règlement.
        assertThat(ecriture.getValue().getDateReference()).isEqualTo(JOUR_FAUTE);
    }

    @Test
    @DisplayName("Les trois verrous sont éprouvés : la ligne, la date d'origine, la date visée")
    void interroge_les_verrous() {
        useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE);

        verify(modificationDateService).verifierLigne(any(LignePenalite.class));
        verify(modificationDateService).verifierVersement(SAISIE_LE, CAISSE, false);
        verify(modificationDateService).verifierNouvelleDate(REELLEMENT_LE, CAISSE);
    }

    @Test
    @DisplayName("Pénalité prise dans un arrêté : rien n'est écrit")
    void ligne_figee() {
        doThrow(new EcritureFigeeException("Un arrêté de compte a déjà compensé cette pénalité."))
                .when(modificationDateService).verifierLigne(any(LignePenalite.class));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(EcritureFigeeException.class);

        verify(encaissementRepository, never()).save(any());
        verify(operationFinanciereRepository, never()).save(any());
    }

    @Test
    @DisplayName("Même date : rien n'est écrit")
    void date_inchangee() {
        useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, SAISIE_LE);

        verify(encaissementRepository, never()).save(any());
        verify(operationFinanciereRepository, never()).save(any());
    }

    @Test
    @DisplayName("Postdater reste fermé")
    void date_future() {
        assertThatThrownBy(() ->
                useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, LocalDate.now().plusDays(1)))
                .isInstanceOf(EncaissementFuturException.class);
    }

    @Test
    @DisplayName("Écriture extournée : le couple se lit à sa date, on ne le rompt pas")
    void ecriture_extournee() {
        OperationFinanciere extournee = operation();
        extournee.setAnnuleLe(LocalDateTime.now());
        when(operationFinanciereRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(extournee));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(EcritureFigeeException.class)
                .hasMessageContaining("extournée");
    }

    @Test
    @DisplayName("Un versement d'une autre pénalité n'est pas déplaçable depuis celle-ci")
    void versement_d_une_autre_ligne() {
        EncaissementPenalite ailleurs = encaissement();
        ailleurs.setLignePenaliteId(999L);
        when(encaissementRepository.findById(ENCAISSEMENT_ID)).thenReturn(Optional.of(ailleurs));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    @DisplayName("Pénalité introuvable : rien ne se passe")
    void ligne_introuvable() {
        when(lignePenaliteRepository.findById(LIGNE_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(LignePenaliteNotFoundException.class);
    }
}
