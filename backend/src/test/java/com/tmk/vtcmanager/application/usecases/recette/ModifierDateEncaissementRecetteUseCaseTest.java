package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.exception.EncaissementFuturException;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
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
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Correction de la date d'un versement de recette.
 *
 * <p>Ce que le use case garantit : le versement et l'écriture qu'il a produite
 * se déplacent <b>ensemble</b> — de là suivent le solde de trésorerie à date, le
 * résultat du mois et l'ancienneté de la créance — et rien d'autre ne bouge, ni
 * le montant, ni la date de référence, qui reste celle de la recette due.
 */
class ModifierDateEncaissementRecetteUseCaseTest {

    private static final Long LIGNE_ID = 77L;
    private static final Long ENCAISSEMENT_ID = 5L;
    private static final Long OPERATION_ID = 900L;
    private static final Long CAISSE = 1L;
    private static final LocalDate SAISIE_LE = LocalDate.of(2026, 4, 10);
    private static final LocalDate REELLEMENT_LE = LocalDate.of(2026, 4, 8);

    private LigneRecetteRepository ligneRecetteRepository;
    private EncaissementRepository encaissementRepository;
    private OperationFinanciereRepository operationFinanciereRepository;
    private ModificationDateEncaissementService modificationDateService;
    private ModifierDateEncaissementRecetteUseCase useCase;

    @BeforeEach
    void setUp() {
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        encaissementRepository = mock(EncaissementRepository.class);
        operationFinanciereRepository = mock(OperationFinanciereRepository.class);
        modificationDateService = mock(ModificationDateEncaissementService.class);

        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne()));
        when(encaissementRepository.findById(ENCAISSEMENT_ID))
                .thenReturn(Optional.of(encaissement()));
        when(operationFinanciereRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(operation()));

        useCase = new ModifierDateEncaissementRecetteUseCase(ligneRecetteRepository,
                encaissementRepository, operationFinanciereRepository, modificationDateService,
                new EncaissementFuturGuard());
    }

    private LigneRecette ligne() {
        return LigneRecette.builder()
                .id(LIGNE_ID)
                .vehiculeId(1L).chauffeurId(2L)
                .dateRecette(LocalDate.of(2026, 4, 7))
                .montantAttendu(new BigDecimal("15000"))
                .montantEncaisse(new BigDecimal("15000"))
                .statut(StatutLigneRecette.ENCAISSE)
                .encaissements(List.of(encaissement()))
                .build();
    }

    private Encaissement encaissement() {
        return Encaissement.builder()
                .id(ENCAISSEMENT_ID)
                .ligneRecetteId(LIGNE_ID)
                .operationFinanciereId(OPERATION_ID)
                .montant(new BigDecimal("15000"))
                .modeEncaissement(ModePaiement.ESPECES)
                .dateEncaissement(SAISIE_LE)
                .build();
    }

    private OperationFinanciere operation() {
        return OperationFinanciere.builder()
                .id(OPERATION_ID)
                .montant(new BigDecimal("15000"))
                .compteTresorerieId(CAISSE)
                .dateOperation(SAISIE_LE)
                .dateReference(LocalDate.of(2026, 4, 7))
                .statut(StatutOperation.ENCAISSE)
                .build();
    }

    @Test
    @DisplayName("Le versement et son écriture partent à la même nouvelle date")
    void deplace_les_deux() {
        useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE);

        ArgumentCaptor<Encaissement> versement = ArgumentCaptor.forClass(Encaissement.class);
        verify(encaissementRepository).save(versement.capture());
        assertThat(versement.getValue().getDateEncaissement()).isEqualTo(REELLEMENT_LE);
        assertThat(versement.getValue().getMontant()).isEqualByComparingTo("15000");

        ArgumentCaptor<OperationFinanciere> ecriture =
                ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository).save(ecriture.capture());
        assertThat(ecriture.getValue().getDateOperation()).isEqualTo(REELLEMENT_LE);
        // La date de référence est la période due, pas la transaction : elle ne suit pas.
        assertThat(ecriture.getValue().getDateReference()).isEqualTo(LocalDate.of(2026, 4, 7));
        assertThat(ecriture.getValue().getMontant()).isEqualByComparingTo("15000");
    }

    @Test
    @DisplayName("Les trois verrous sont éprouvés : la ligne, la date d'origine, la date visée")
    void interroge_les_verrous() {
        useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE);

        verify(modificationDateService).verifierLigne(any(LigneRecette.class));
        verify(modificationDateService).verifierVersement(SAISIE_LE, CAISSE, false);
        verify(modificationDateService).verifierNouvelleDate(REELLEMENT_LE, CAISSE);
    }

    @Test
    @DisplayName("Même date : rien n'est écrit")
    void date_inchangee() {
        useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, SAISIE_LE);

        verify(encaissementRepository, never()).save(any());
        verify(operationFinanciereRepository, never()).save(any());
        verify(modificationDateService, never()).verifierLigne(any(LigneRecette.class));
    }

    @Test
    @DisplayName("Postdater reste fermé : un encaissement constate de l'argent déjà compté")
    void date_future() {
        assertThatThrownBy(() ->
                useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, LocalDate.now().plusDays(1)))
                .isInstanceOf(EncaissementFuturException.class);

        verify(encaissementRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un arrêté qui ferme la ligne arrête tout avant la moindre écriture")
    void ligne_figee() {
        doThrow(new EcritureFigeeException("Un arrêté de compte a déjà compensé cette recette."))
                .when(modificationDateService).verifierLigne(any(LigneRecette.class));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(EcritureFigeeException.class);

        verify(encaissementRepository, never()).save(any());
        verify(operationFinanciereRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une caisse comptée à la date visée refuse le déplacement")
    void nouvelle_date_figee() {
        doThrow(new EcritureFigeeException("La caisse a été comptée."))
                .when(modificationDateService).verifierNouvelleDate(any(), any());

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(EcritureFigeeException.class);

        verify(encaissementRepository, never()).save(any());
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

        verify(encaissementRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un versement d'une autre ligne n'est pas déplaçable depuis celle-ci")
    void versement_d_une_autre_ligne() {
        Encaissement ailleurs = encaissement();
        ailleurs.setLigneRecetteId(999L);
        when(encaissementRepository.findById(ENCAISSEMENT_ID)).thenReturn(Optional.of(ailleurs));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    @DisplayName("Ligne introuvable : rien ne se passe")
    void ligne_introuvable() {
        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(LigneRecetteNotFoundException.class);
    }

    @Test
    @DisplayName("Versement hérité sans écriture : la date se corrige quand même")
    void sans_ecriture_liee() {
        Encaissement sansEcriture = encaissement();
        sansEcriture.setOperationFinanciereId(null);
        when(encaissementRepository.findById(ENCAISSEMENT_ID))
                .thenReturn(Optional.of(sansEcriture));

        useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE);

        verify(encaissementRepository).save(any());
        verify(operationFinanciereRepository, never()).save(any());
        // Sans caisse connue, seul le verrou de période peut mordre.
        verify(modificationDateService).verifierVersement(SAISIE_LE, null, false);
    }

    @Test
    @DisplayName("Un versement extourné est présenté comme tel au garde-fou")
    void versement_extourne_signale() {
        Encaissement extourne = encaissement();
        extourne.setAnnuleLe(LocalDateTime.now());
        when(encaissementRepository.findById(ENCAISSEMENT_ID)).thenReturn(Optional.of(extourne));
        doThrow(new EcritureFigeeException("Ce versement a été extourné."))
                .when(modificationDateService)
                .verifierVersement(any(), any(), anyBoolean());

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, ENCAISSEMENT_ID, REELLEMENT_LE))
                .isInstanceOf(EcritureFigeeException.class);

        verify(modificationDateService).verifierVersement(SAISIE_LE, CAISSE, true);
    }
}
