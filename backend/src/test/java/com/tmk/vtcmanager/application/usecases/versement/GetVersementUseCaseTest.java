package com.tmk.vtcmanager.application.usecases.versement;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.versement.ImputationVersement;
import com.tmk.vtcmanager.application.domain.versement.NatureImputation;
import com.tmk.vtcmanager.application.domain.versement.Versement;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import com.tmk.vtcmanager.application.services.LectureImputationService;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;

/**
 * Lecture d'une pièce de caisse : chaque écriture est rendue du côté de la
 * créance qu'elle solde, avec ce qu'il y reste à devoir — ce que l'écriture,
 * seule, ne sait pas dire.
 */
@DisplayName("Lecture d'un versement")
class GetVersementUseCaseTest {

    private static final UUID VERSEMENT = UUID.fromString("0b6f8a2e-0e6a-4c4e-9d1d-6f0a3c1b2d44");
    private static final LocalDate LA_JOURNEE = LocalDate.of(2026, 9, 10);
    private static final LocalDate VERSE_LE = LocalDate.of(2026, 9, 11);

    private OperationFinanciereRepository operationRepository;
    private EncaissementRepository encaissementRepository;
    private EncaissementCotisationRepository encaissementCotisationRepository;
    private LigneRecetteRepository ligneRecetteRepository;
    private LigneCotisationRepository ligneCotisationRepository;
    private GetVersementUseCase useCase;

    private OperationFinanciere ecritureRecette;
    private OperationFinanciere ecritureCotisation;

    @BeforeEach
    void setUp() {
        operationRepository = mock(OperationFinanciereRepository.class);
        encaissementRepository = mock(EncaissementRepository.class);
        encaissementCotisationRepository = mock(EncaissementCotisationRepository.class);
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        ligneCotisationRepository = mock(LigneCotisationRepository.class);

        ecritureRecette = ecriture(501L, "ENC-2026-000501", "15000");
        ecritureCotisation = ecriture(502L, "COT-2026-000502", "2000");
        when(operationRepository.findByVersementId(VERSEMENT))
                .thenReturn(List.of(ecritureRecette, ecritureCotisation));

        when(encaissementRepository.findByOperationFinanciereId(501L))
                .thenReturn(Optional.of(Encaissement.builder().ligneRecetteId(1L).build()));
        when(encaissementRepository.findByOperationFinanciereId(502L)).thenReturn(Optional.empty());
        when(encaissementCotisationRepository.findByOperationFinanciereId(502L))
                .thenReturn(Optional.of(EncaissementCotisation.builder().ligneCotisationId(91L).build()));

        when(ligneRecetteRepository.findById(1L)).thenReturn(Optional.of(LigneRecette.builder()
                .id(1L).montantAttendu(new BigDecimal("20000"))
                .montantEncaisse(new BigDecimal("15000")).build()));
        when(ligneCotisationRepository.findById(91L)).thenReturn(Optional.of(LigneCotisation.builder()
                .id(91L).nomCotisation("Cotisation carburant")
                .montantDu(new BigDecimal("2000")).montantEncaisse(new BigDecimal("2000")).build()));

        useCase = new GetVersementUseCase(operationRepository, new LectureImputationService(
                encaissementRepository, encaissementCotisationRepository,
                mock(EncaissementPenaliteRepository.class), ligneRecetteRepository,
                ligneCotisationRepository, mock(LignePenaliteRepository.class)));
    }

    private static OperationFinanciere ecriture(Long id, String reference, String montant) {
        return OperationFinanciere.builder()
                .id(id).reference(reference)
                .montant(new BigDecimal(montant))
                .modePaiement(ModePaiement.ESPECES)
                .dateOperation(VERSE_LE).dateReference(LA_JOURNEE)
                .statut(StatutOperation.ENCAISSE)
                .versementId(VERSEMENT)
                .chauffeur(Chauffeur.builder().id(3L).prenom("Jean").nom("Kouassi")
                        .telephone("0712345678").build())
                .vehicule(Vehicule.builder().id(7L).immatriculation("1234 AB 01").build())
                .build();
    }

    @Test
    @DisplayName("chaque écriture est lue du côté de la créance qu'elle solde")
    void imputationsParCreance() {
        Versement versement = useCase.executer(VERSEMENT);

        assertThat(versement.chauffeurNom()).isEqualTo("Jean Kouassi");
        assertThat(versement.chauffeurTelephone()).isEqualTo("0712345678");
        assertThat(versement.vehiculeImmatriculation()).isEqualTo("1234 AB 01");
        assertThat(versement.dateEncaissement()).isEqualTo(VERSE_LE);
        assertThat(versement.total()).isEqualByComparingTo("17000");

        ImputationVersement recette = versement.imputations().get(0);
        assertThat(recette.nature()).isEqualTo(NatureImputation.RECETTE);
        assertThat(recette.libelle()).isEqualTo("Recette");
        assertThat(recette.ligneId()).isEqualTo(1L);
        assertThat(recette.resteDu()).isEqualByComparingTo("5000");

        ImputationVersement cotisation = versement.imputations().get(1);
        assertThat(cotisation.nature()).isEqualTo(NatureImputation.COTISATION);
        assertThat(cotisation.libelle()).isEqualTo("Cotisation carburant");
        assertThat(cotisation.resteDu()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("une imputation extournée reste au versement, mais sort de son total")
    void imputationExtournee() {
        ecritureCotisation.setAnnuleLe(LocalDateTime.of(2026, 9, 12, 9, 0));

        Versement versement = useCase.executer(VERSEMENT);

        assertThat(versement.imputations()).hasSize(2);
        assertThat(versement.imputations().get(1).annulee()).isTrue();
        assertThat(versement.total()).isEqualByComparingTo("15000");
    }

    @Test
    @DisplayName("une recette au montant réel n'annonce aucun reste dû")
    void recetteAuReel() {
        when(ligneRecetteRepository.findById(1L)).thenReturn(Optional.of(LigneRecette.builder()
                .id(1L).montantEncaisse(new BigDecimal("15000")).build()));

        assertThat(useCase.executer(VERSEMENT).imputations().get(0).resteDu()).isNull();
    }

    @Test
    @DisplayName("un versement inconnu est introuvable")
    void introuvable() {
        UUID inconnu = UUID.randomUUID();
        when(operationRepository.findByVersementId(inconnu)).thenReturn(List.of());

        assertThatThrownBy(() -> useCase.executer(inconnu))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
