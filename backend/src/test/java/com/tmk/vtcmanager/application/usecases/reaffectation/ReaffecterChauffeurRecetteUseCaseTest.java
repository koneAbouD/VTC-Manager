package com.tmk.vtcmanager.application.usecases.reaffectation;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.reaffectation.ReaffectationChauffeur;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.ReaffectationImpossibleException;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import com.tmk.vtcmanager.application.ports.persistence.ReaffectationChauffeurRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.NotificationReaffectationService;
import com.tmk.vtcmanager.application.services.ReaffectationChauffeurService;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import com.tmk.vtcmanager.application.usecases.recette.ReaffecterChauffeurRecetteUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Changement de débiteur d'une recette.
 *
 * <p>L'opération ne déplace aucun montant : ce qui est éprouvé ici, c'est
 * <em>quand</em> elle est permise, et ce qu'elle emmène dans son sillage quand
 * elle l'est. Un refus doit intervenir <b>avant la première écriture</b> — une
 * réaffectation à moitié faite serait pire que pas de réaffectation du tout.
 */
class ReaffecterChauffeurRecetteUseCaseTest {

    private static final Long LIGNE_ID = 77L;
    private static final Long VEHICULE = 5L;
    private static final Long ANCIEN = 1L;
    private static final Long NOUVEAU = 2L;
    private static final LocalDate JOUR = LocalDate.of(2026, 4, 6);
    private static final String MOTIF = "C'est Aya qui a pris le service ce matin-là.";

    private LigneRecetteRepository ligneRecetteRepository;
    private LigneCotisationRepository ligneCotisationRepository;
    private ChauffeurRepository chauffeurRepository;
    private ArreteCompteRepository arreteCompteRepository;
    private OperationFinanciereRepository operationRepository;
    private LignePenaliteRepository lignePenaliteRepository;
    private ReaffectationChauffeurRepository journalRepository;
    private PaiementRepository paiementRepository;
    private CloturePeriodeRepository cloturePeriodeRepository;
    private ClotureCaisseRepository clotureCaisseRepository;
    private NotificationReaffectationService notificationService;
    private ReaffecterChauffeurRecetteUseCase useCase;

    @BeforeEach
    void setUp() {
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        chauffeurRepository = mock(ChauffeurRepository.class);
        arreteCompteRepository = mock(ArreteCompteRepository.class);
        operationRepository = mock(OperationFinanciereRepository.class);
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        journalRepository = mock(ReaffectationChauffeurRepository.class);
        paiementRepository = mock(PaiementRepository.class);
        cloturePeriodeRepository = mock(CloturePeriodeRepository.class);
        clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        notificationService = mock(NotificationReaffectationService.class);

        // Livres ouverts, aucun arrêté, aucun paiement en vol, journée libre.
        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.empty());
        when(clotureCaisseRepository.findDerniereDateClotureToutesCaisses()).thenReturn(Optional.empty());
        when(clotureCaisseRepository.findDernieresClotureParCompte()).thenReturn(Map.of());
        when(arreteCompteRepository.existeLigneValidePourDocument(any(), anyLong())).thenReturn(false);
        when(paiementRepository.existeEnCours(any(), anyLong())).thenReturn(false);
        when(ligneRecetteRepository.findByChauffeurIdAndDateRecette(anyLong(), any()))
                .thenReturn(List.of());
        when(ligneCotisationRepository.findByChauffeurIdAndDateCotisation(anyLong(), any()))
                .thenReturn(List.of());
        when(lignePenaliteRepository.findByLigneRecetteId(anyLong())).thenReturn(List.of());
        when(chauffeurRepository.findById(NOUVEAU)).thenReturn(Optional.of(chauffeur(NOUVEAU, "Aya", "Traoré")));
        when(operationRepository.reaffecterChauffeurDesEncaissements(any(), anyLong(), anyLong(), anyString()))
                .thenReturn(0);

        VerrouArreteService verrouArreteService =
                new VerrouArreteService(cloturePeriodeRepository, clotureCaisseRepository);
        ReaffectationChauffeurService service = new ReaffectationChauffeurService(
                verrouArreteService, arreteCompteRepository, paiementRepository,
                ligneRecetteRepository, ligneCotisationRepository, lignePenaliteRepository);

        AuteurCourant auteurCourant = () -> "akone";
        useCase = new ReaffecterChauffeurRecetteUseCase(ligneRecetteRepository, chauffeurRepository,
                arreteCompteRepository, operationRepository, lignePenaliteRepository,
                journalRepository, service, notificationService, auteurCourant);
    }

    // ── Fixtures ────────────────────────────────────────────────────────────

    private LigneRecette ligne(StatutLigneRecette statut) {
        return LigneRecette.builder()
                .id(LIGNE_ID).vehiculeId(VEHICULE).chauffeurId(ANCIEN)
                .vehiculeImmatriculation("AB-4521-CI").chauffeurNom("Kouassi Yao")
                .dateRecette(JOUR)
                .montantAttendu(BigDecimal.valueOf(15_000))
                .montantEncaisse(BigDecimal.ZERO)
                .statut(statut).encaissements(new ArrayList<>())
                .build();
    }

    private void enBase(LigneRecette ligne) {
        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne));
    }

    private static Chauffeur chauffeur(Long id, String prenom, String nom) {
        Chauffeur c = new Chauffeur();
        c.setId(id);
        c.setPrenom(prenom);
        c.setNom(nom);
        return c;
    }

    private static LignePenalite penalite(StatutLignePenalite statut, int encaisse) {
        return LignePenalite.builder()
                .id(300L).vehiculeId(VEHICULE).chauffeurId(ANCIEN).ligneRecetteId(LIGNE_ID)
                .montant(BigDecimal.valueOf(5_000))
                .montantEncaisse(BigDecimal.valueOf(encaisse))
                .statut(statut).encaissements(new ArrayList<>())
                .build();
    }

    private void aucuneEcriture() {
        verify(operationRepository, never()).detacherVersementsDesEncaissements(any(), anyLong());
        verify(ligneRecetteRepository, never()).reaffecterChauffeur(anyLong(), anyLong());
        verifyNoInteractions(journalRepository);
    }

    // ── Cas nominal ─────────────────────────────────────────────────────────

    @Nested
    @DisplayName("Réaffectation acceptée")
    class Nominal {

        @Test
        @DisplayName("déplace la ligne, ses écritures vivantes, et laisse une trace signée")
        void nominal() {
            LigneRecette avant = ligne(StatutLigneRecette.PARTIELLEMENT_ENCAISSE);
            avant.setMontantEncaisse(BigDecimal.valueOf(10_000));
            enBase(avant);
            when(operationRepository.reaffecterChauffeurDesEncaissements(
                    TypeDocumentCreance.RECETTE, LIGNE_ID, NOUVEAU, "akone")).thenReturn(2);

            useCase.executer(LIGNE_ID, NOUVEAU, MOTIF);

            verify(ligneRecetteRepository).reaffecterChauffeur(LIGNE_ID, NOUVEAU);
            verify(operationRepository).reaffecterChauffeurDesEncaissements(
                    TypeDocumentCreance.RECETTE, LIGNE_ID, NOUVEAU, "akone");
            // Une moitié de versement qui change de payeur défait la pièce de caisse.
            verify(operationRepository).detacherVersementsDesEncaissements(TypeDocumentCreance.RECETTE, LIGNE_ID);

            ArgumentCaptor<ReaffectationChauffeur> trace =
                    ArgumentCaptor.forClass(ReaffectationChauffeur.class);
            verify(journalRepository).save(trace.capture());
            assertThat(trace.getValue()).satisfies(t -> {
                assertThat(t.getDocument()).isEqualTo(TypeDocumentCreance.RECETTE);
                assertThat(t.getDocumentId()).isEqualTo(LIGNE_ID);
                assertThat(t.getAncienChauffeurId()).isEqualTo(ANCIEN);
                assertThat(t.getNouveauChauffeurId()).isEqualTo(NOUVEAU);
                assertThat(t.getMotif()).isEqualTo(MOTIF);
                assertThat(t.getOperationsReprises()).isEqualTo(2);
                assertThat(t.getCreatedBy()).isEqualTo("akone");
            });
        }

        @Test
        @DisplayName("sérialise avec les arrêtés : le verrou est pris avant toute lecture décisive")
        void prendLeVerrou() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));

            useCase.executer(LIGNE_ID, NOUVEAU, MOTIF);

            verify(arreteCompteRepository).verrouillerExecution();
        }

        @Test
        @DisplayName("prévient les deux chauffeurs, celui qu'on décharge comme celui qu'on impute")
        void notifie() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));

            useCase.executer(LIGNE_ID, NOUVEAU, MOTIF);

            verify(notificationService).ligneReaffectee(
                    eq(TypeDocumentCreance.RECETTE), eq(LIGNE_ID), eq(JOUR), eq("AB-4521-CI"),
                    any(), eq(ANCIEN), eq("Kouassi Yao"), eq(NOUVEAU), eq("Aya Traoré"));
        }

        @Test
        @DisplayName("emmène la pénalité de recette non versée restée en attente")
        void cascadePenalite() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            when(lignePenaliteRepository.findByLigneRecetteId(LIGNE_ID))
                    .thenReturn(List.of(penalite(StatutLignePenalite.EN_ATTENTE, 0)));

            useCase.executer(LIGNE_ID, NOUVEAU, MOTIF);

            verify(lignePenaliteRepository).reaffecterChauffeur(300L, NOUVEAU);
        }

        @Test
        @DisplayName("laisse en place la pénalité annulée : elle n'engage plus personne")
        void ignorePenaliteAnnulee() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            when(lignePenaliteRepository.findByLigneRecetteId(LIGNE_ID))
                    .thenReturn(List.of(penalite(StatutLignePenalite.ANNULEE, 0)));

            useCase.executer(LIGNE_ID, NOUVEAU, MOTIF);

            verify(lignePenaliteRepository, never()).reaffecterChauffeur(anyLong(), anyLong());
            verify(ligneRecetteRepository).reaffecterChauffeur(LIGNE_ID, NOUVEAU);
        }

        @Test
        @DisplayName("le même chauffeur ne produit ni écriture ni trace")
        void memeChauffeur() {
            LigneRecette existante = ligne(StatutLigneRecette.EN_ATTENTE);
            enBase(existante);

            assertThat(useCase.executer(LIGNE_ID, ANCIEN, null)).isSameAs(existante);
            aucuneEcriture();
        }
    }

    // ── Refus ───────────────────────────────────────────────────────────────

    @Nested
    @DisplayName("Réaffectation refusée")
    class Refus {

        @Test
        @DisplayName("motif vide : une créance qui change de main doit s'expliquer")
        void motifObligatoire() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, "   "))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("motif");
            aucuneEcriture();
        }

        @Test
        @DisplayName("ligne annulée : elle n'est due par personne")
        void ligneAnnulee() {
            enBase(ligne(StatutLigneRecette.ANNULEE));

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class)
                    .hasMessageContaining("Restaurez-la");
            aucuneEcriture();
        }

        @Test
        @DisplayName("arrêté de compte : le décompte nominatif est parti")
        void arreteEngage() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            when(arreteCompteRepository.existeLigneValidePourDocument(
                    TypeDocumentCreance.RECETTE, LIGNE_ID)).thenReturn(true);

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class)
                    .hasMessageContaining("arrêté de compte");
            aucuneEcriture();
        }

        @Test
        @DisplayName("période clôturée : les états du mois ont été arrêtés")
        void periodeClose() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.of(
                    CloturePeriode.builder()
                            .annee(JOUR.getYear()).mois(JOUR.getMonthValue()).build()));

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class)
                    .hasMessageContaining("clôturée");
            aucuneEcriture();
        }

        @Test
        @DisplayName("caisse arrêtée sur la journée : elle est close")
        void caisseArretee() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            when(clotureCaisseRepository.findDerniereDateClotureToutesCaisses())
                    .thenReturn(Optional.of(JOUR.plusDays(1)));

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class)
                    .hasMessageContaining("caisse");
            aucuneEcriture();
        }

        @Test
        @DisplayName("paiement mobile money en vol : son webhook nommerait l'ancien chauffeur")
        void paiementEnCours() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            when(paiementRepository.existeEnCours(TypeCiblePaiement.RECETTE, LIGNE_ID)).thenReturn(true);

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class)
                    .hasMessageContaining("paiement mobile money");
            aucuneEcriture();
        }

        @Test
        @DisplayName("chauffeur visé déjà sur un autre véhicule ce jour-là — via une recette")
        void dejaSurUnAutreVehicule() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            LigneRecette ailleurs = LigneRecette.builder()
                    .id(88L).vehiculeId(9L).chauffeurId(NOUVEAU).vehiculeImmatriculation("CD-1180-CI")
                    .dateRecette(JOUR).statut(StatutLigneRecette.ENCAISSE).build();
            when(ligneRecetteRepository.findByChauffeurIdAndDateRecette(NOUVEAU, JOUR))
                    .thenReturn(List.of(ailleurs));

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class)
                    .hasMessageContaining("CD-1180-CI")
                    .hasMessageContaining("deux véhicules le même jour");
            aucuneEcriture();
        }

        @Test
        @DisplayName("chauffeur visé déjà sur un autre véhicule ce jour-là — via une cotisation")
        void dejaSurUnAutreVehiculeParCotisation() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            LigneCotisation ailleurs = LigneCotisation.builder()
                    .id(91L).vehiculeId(9L).chauffeurId(NOUVEAU).vehiculeImmatriculation("CD-1180-CI")
                    .dateCotisation(JOUR).nomCotisation("Épargne")
                    .montantDu(BigDecimal.valueOf(1_000))
                    .statut(StatutLigneCotisation.EN_ATTENTE).build();
            when(ligneCotisationRepository.findByChauffeurIdAndDateCotisation(NOUVEAU, JOUR))
                    .thenReturn(List.of(ailleurs));

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class)
                    .hasMessageContaining("CD-1180-CI");
            aucuneEcriture();
        }

        @Test
        @DisplayName("une ligne annulée du chauffeur visé, même véhicule et même jour : "
                + "la contrainte d'unicité refuserait, on l'explique avant")
        void doublonAvecLigneAnnulee() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            LigneRecette annulee = LigneRecette.builder()
                    .id(88L).vehiculeId(VEHICULE).chauffeurId(NOUVEAU)
                    .vehiculeImmatriculation("AB-4521-CI").dateRecette(JOUR)
                    .statut(StatutLigneRecette.ANNULEE).build();
            when(ligneRecetteRepository.findByChauffeurIdAndDateRecette(NOUVEAU, JOUR))
                    .thenReturn(List.of(annulee));

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class)
                    .hasMessageContaining("annulée")
                    .hasMessageContaining("Restaurez-la");
            aucuneEcriture();
        }

        @Test
        @DisplayName("pénalité déjà encaissée : la sanction s'est appliquée à quelqu'un")
        void penaliteEncaissee() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            when(lignePenaliteRepository.findByLigneRecetteId(LIGNE_ID))
                    .thenReturn(List.of(penalite(StatutLignePenalite.ENCAISSEE, 5_000)));

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class)
                    .hasMessageContaining("pénalité");
            aucuneEcriture();
        }

        @Test
        @DisplayName("pénalité déjà exécutée (buzzer) : le fait s'est produit sur l'ancien chauffeur")
        void penaliteExecutee() {
            enBase(ligne(StatutLigneRecette.EN_ATTENTE));
            when(lignePenaliteRepository.findByLigneRecetteId(LIGNE_ID))
                    .thenReturn(List.of(penalite(StatutLignePenalite.EXECUTEE, 0)));

            assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                    .isInstanceOf(ReaffectationImpossibleException.class);
            aucuneEcriture();
        }
    }
}
