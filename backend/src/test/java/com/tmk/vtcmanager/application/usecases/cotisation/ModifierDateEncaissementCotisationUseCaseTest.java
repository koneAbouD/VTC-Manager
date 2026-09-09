package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.exception.EncaissementFuturException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.EncaissementFuturGuard;
import com.tmk.vtcmanager.application.services.ModificationDateEncaissementService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
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
 * Correction de la date d'un versement de cotisation.
 *
 * <p>Une cotisation encaissée est un dépôt détenu pour le chauffeur : sa date
 * dit à partir de quand il l'est, donc ce que le fonds à date et un futur arrêté
 * de compte y liront. Le use case déplace le versement et son écriture, et
 * s'arrête net dès qu'un arrêté a déjà rendu ce dépôt.
 */
class ModifierDateEncaissementCotisationUseCaseTest {

    private static final Long LIGNE_ID = 42L;
    private static final Long ENCAISSEMENT_ID = 8L;
    private static final Long OPERATION_ID = 700L;
    private static final Long CAISSE = 1L;
    private static final LocalDate SAISIE_LE = LocalDate.of(2026, 4, 10);
    private static final LocalDate REELLEMENT_LE = LocalDate.of(2026, 4, 8);

    private LigneCotisationRepository ligneCotisationRepository;
    private EncaissementCotisationRepository encaissementRepository;
    private OperationFinanciereRepository operationFinanciereRepository;
    private ModificationDateEncaissementService modificationDateService;
    private ModifierDateEncaissementCotisationUseCase useCase;

    @BeforeEach
    void setUp() {
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        encaissementRepository = mock(EncaissementCotisationRepository.class);
        operationFinanciereRepository = mock(OperationFinanciereRepository.class);
        modificationDateService = mock(ModificationDateEncaissementService.class);

        when(ligneCotisationRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne()));
        when(encaissementRepository.findById(ENCAISSEMENT_ID))
                .thenReturn(Optional.of(encaissement()));
        when(operationFinanciereRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(operation()));

        useCase = new ModifierDateEncaissementCotisationUseCase(ligneCotisationRepository,
                encaissementRepository, operationFinanciereRepository, modificationDateService,
                new EncaissementFuturGuard());
    }

    private LigneCotisation ligne() {
        return LigneCotisation.builder()
                .id(LIGNE_ID)
                .vehiculeId(1L).chauffeurId(2L)
                .dateCotisation(LocalDate.of(2026, 4, 7))
                .nomCotisation("Fonds de garantie")
                .montantDu(new BigDecimal("2000"))
                .montantEncaisse(new BigDecimal("2000"))
                .statut(StatutLigneCotisation.ENCAISSE)
                .encaissements(List.of(encaissement()))
                .build();
    }

    private EncaissementCotisation encaissement() {
        return EncaissementCotisation.builder()
                .id(ENCAISSEMENT_ID)
                .ligneCotisationId(LIGNE_ID)
                .operationFinanciereId(OPERATION_ID)
                .montant(new BigDecimal("2000"))
                .modeEncaissement(ModePaiement.ESPECES)
                .dateEncaissement(SAISIE_LE)
                .build();
    }

    private OperationFinanciere operation() {
        return OperationFinanciere.builder()
                .id(OPERATION_ID)
                .montant(new BigDecimal("2000"))
                .compteTresorerieId(CAISSE)
                .dateOperation(SAISIE_LE)
                .dateReference(LocalDate.of(2026, 4, 7))
                .statut(StatutOperation.ENCAISSE)
                .build();
    }

    @Test
    @DisplayName("Le dépôt et son écriture partent à la même nouvelle date")
    void deplace_les_deux() {
        useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE);

        ArgumentCaptor<EncaissementCotisation> versement =
                ArgumentCaptor.forClass(EncaissementCotisation.class);
        verify(encaissementRepository).save(versement.capture());
        assertThat(versement.getValue().getDateEncaissement()).isEqualTo(REELLEMENT_LE);

        ArgumentCaptor<OperationFinanciere> ecriture =
                ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository).save(ecriture.capture());
        assertThat(ecriture.getValue().getDateOperation()).isEqualTo(REELLEMENT_LE);
        assertThat(ecriture.getValue().getDateReference()).isEqualTo(LocalDate.of(2026, 4, 7));
    }

    @Test
    @DisplayName("Les trois verrous sont éprouvés : la ligne, la date d'origine, la date visée")
    void interroge_les_verrous() {
        useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE);

        verify(modificationDateService).verifierLigne(any(LigneCotisation.class));
        verify(modificationDateService).verifierVersement(SAISIE_LE, CAISSE, false);
        verify(modificationDateService).verifierNouvelleDate(REELLEMENT_LE, CAISSE);
    }

    @Test
    @DisplayName("Dépôt déjà restitué par un arrêté : la date ne bouge plus")
    void depot_restitue() {
        doThrow(new EcritureFigeeException("Un arrêté de compte a déjà restitué cette cotisation."))
                .when(modificationDateService).verifierLigne(any(LigneCotisation.class));

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
    @DisplayName("Un versement d'une autre cotisation n'est pas déplaçable depuis celle-ci")
    void versement_d_une_autre_ligne() {
        EncaissementCotisation ailleurs = encaissement();
        ailleurs.setLigneCotisationId(999L);
        when(encaissementRepository.findById(ENCAISSEMENT_ID)).thenReturn(Optional.of(ailleurs));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
