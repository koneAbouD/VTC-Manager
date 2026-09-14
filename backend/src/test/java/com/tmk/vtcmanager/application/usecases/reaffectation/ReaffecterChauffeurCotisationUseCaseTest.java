package com.tmk.vtcmanager.application.usecases.reaffectation;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.reaffectation.ReaffectationChauffeur;
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
import com.tmk.vtcmanager.application.usecases.cotisation.ReaffecterChauffeurCotisationUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
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
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Changement de titulaire d'une cotisation.
 *
 * <p>Une cotisation encaissée n'est pas une dette : c'est un <b>dépôt détenu
 * pour le compte du chauffeur</b>, que l'arrêté lui rendra. D'où le refus dès
 * qu'un arrêté y a touché — même partiellement, et même quand la ligne n'a pas
 * basculé en RESTITUEE parce qu'elle n'était pas soldée.
 */
class ReaffecterChauffeurCotisationUseCaseTest {

    private static final Long LIGNE_ID = 41L;
    private static final Long VEHICULE = 5L;
    private static final Long ANCIEN = 1L;
    private static final Long NOUVEAU = 2L;
    private static final LocalDate JOUR = LocalDate.of(2026, 4, 6);
    private static final String MOTIF = "Dépôt versé par Aya, pas par Kouassi.";

    private LigneCotisationRepository ligneCotisationRepository;
    private LigneRecetteRepository ligneRecetteRepository;
    private ChauffeurRepository chauffeurRepository;
    private ArreteCompteRepository arreteCompteRepository;
    private OperationFinanciereRepository operationRepository;
    private ReaffectationChauffeurRepository journalRepository;
    private PaiementRepository paiementRepository;
    private ReaffecterChauffeurCotisationUseCase useCase;

    @BeforeEach
    void setUp() {
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        chauffeurRepository = mock(ChauffeurRepository.class);
        arreteCompteRepository = mock(ArreteCompteRepository.class);
        operationRepository = mock(OperationFinanciereRepository.class);
        journalRepository = mock(ReaffectationChauffeurRepository.class);
        paiementRepository = mock(PaiementRepository.class);
        CloturePeriodeRepository cloturePeriodeRepository = mock(CloturePeriodeRepository.class);
        ClotureCaisseRepository clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        NotificationReaffectationService notificationService =
                mock(NotificationReaffectationService.class);

        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.empty());
        when(clotureCaisseRepository.findDerniereDateClotureToutesCaisses()).thenReturn(Optional.empty());
        when(clotureCaisseRepository.findDernieresClotureParCompte()).thenReturn(Map.of());
        when(paiementRepository.existeEnCours(any(), anyLong())).thenReturn(false);
        when(ligneRecetteRepository.findByChauffeurIdAndDateRecette(anyLong(), any())).thenReturn(List.of());
        when(ligneCotisationRepository.findByChauffeurIdAndDateCotisation(anyLong(), any()))
                .thenReturn(List.of());
        when(chauffeurRepository.findById(NOUVEAU)).thenReturn(Optional.of(chauffeur()));
        when(operationRepository.reaffecterChauffeurDesEncaissements(any(), anyLong(), anyLong(), anyString()))
                .thenReturn(0);

        // Rien ne s'adosse à une cotisation : le service ne consultera jamais ce
        // dépôt, mais il en a besoin pour la branche recette.
        LignePenaliteRepository lignePenaliteRepository = mock(LignePenaliteRepository.class);
        ReaffectationChauffeurService service = new ReaffectationChauffeurService(
                new VerrouArreteService(cloturePeriodeRepository, clotureCaisseRepository),
                arreteCompteRepository, paiementRepository,
                ligneRecetteRepository, ligneCotisationRepository, lignePenaliteRepository);

        AuteurCourant auteurCourant = () -> "akone";
        useCase = new ReaffecterChauffeurCotisationUseCase(ligneCotisationRepository, chauffeurRepository,
                arreteCompteRepository, operationRepository, journalRepository, service,
                notificationService, auteurCourant);
    }

    private LigneCotisation ligne(StatutLigneCotisation statut, Long arreteId) {
        return LigneCotisation.builder()
                .id(LIGNE_ID).vehiculeId(VEHICULE).chauffeurId(ANCIEN)
                .vehiculeImmatriculation("AB-4521-CI").chauffeurNom("Kouassi Yao")
                .dateCotisation(JOUR).nomCotisation("Épargne")
                .montantDu(BigDecimal.valueOf(1_000)).montantEncaisse(BigDecimal.ZERO)
                .montantRestitue(BigDecimal.ZERO)
                .statut(statut).arreteId(arreteId).encaissements(new ArrayList<>())
                .build();
    }

    private void enBase(LigneCotisation ligne) {
        when(ligneCotisationRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne));
    }

    private static Chauffeur chauffeur() {
        Chauffeur c = new Chauffeur();
        c.setId(NOUVEAU);
        c.setPrenom("Aya");
        c.setNom("Traoré");
        return c;
    }

    @Test
    @DisplayName("déplace le dépôt, ses écritures, et laisse une trace signée")
    void nominal() {
        enBase(ligne(StatutLigneCotisation.ENCAISSE, null));
        when(operationRepository.reaffecterChauffeurDesEncaissements(
                TypeDocumentCreance.COTISATION, LIGNE_ID, NOUVEAU, "akone")).thenReturn(1);

        useCase.executer(LIGNE_ID, NOUVEAU, MOTIF);

        // Une moitié de versement qui change de payeur défait la pièce de caisse.
        verify(operationRepository).detacherVersementsDesEncaissements(TypeDocumentCreance.COTISATION, LIGNE_ID);

        verify(ligneCotisationRepository).reaffecterChauffeur(LIGNE_ID, NOUVEAU);
        ArgumentCaptor<ReaffectationChauffeur> trace =
                ArgumentCaptor.forClass(ReaffectationChauffeur.class);
        verify(journalRepository).save(trace.capture());
        assertThat(trace.getValue().getDocument()).isEqualTo(TypeDocumentCreance.COTISATION);
        assertThat(trace.getValue().getOperationsReprises()).isEqualTo(1);
    }

    @Test
    @DisplayName("cotisation restituée : le décompte nominatif est parti")
    void restituee() {
        enBase(ligne(StatutLigneCotisation.RESTITUEE, 12L));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                .isInstanceOf(ReaffectationImpossibleException.class)
                .hasMessageContaining("arrêté de compte");
        verify(ligneCotisationRepository, never()).reaffecterChauffeur(anyLong(), anyLong());
    }

    @Test
    @DisplayName("partiellement restituée : le statut n'a pas bougé, l'arrêté rattaché la rattrape")
    void partiellementRestituee() {
        enBase(ligne(StatutLigneCotisation.PARTIELLEMENT_ENCAISSE, 12L));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                .isInstanceOf(ReaffectationImpossibleException.class)
                .hasMessageContaining("arrêté de compte");
        verify(ligneCotisationRepository, never()).reaffecterChauffeur(anyLong(), anyLong());
    }

    @Test
    @DisplayName("même nom, même véhicule, même jour chez le chauffeur visé : ce serait un doublon")
    void doublonDeNom() {
        enBase(ligne(StatutLigneCotisation.EN_ATTENTE, null));
        LigneCotisation memeNom = LigneCotisation.builder()
                .id(99L).vehiculeId(VEHICULE).chauffeurId(NOUVEAU).dateCotisation(JOUR)
                .nomCotisation("épargne")   // la normalisation doit les reconnaître identiques
                .montantDu(BigDecimal.valueOf(1_000))
                .statut(StatutLigneCotisation.EN_ATTENTE).build();
        when(ligneCotisationRepository.findByChauffeurIdAndDateCotisation(NOUVEAU, JOUR))
                .thenReturn(List.of(memeNom));

        assertThatThrownBy(() -> useCase.executer(LIGNE_ID, NOUVEAU, MOTIF))
                .isInstanceOf(ReaffectationImpossibleException.class)
                .hasMessageContaining("doublon");
        verify(ligneCotisationRepository, never()).reaffecterChauffeur(anyLong(), anyLong());
    }

    @Test
    @DisplayName("un autre nom de cotisation, même véhicule : rien ne s'y oppose")
    void autreNomAccepte() {
        enBase(ligne(StatutLigneCotisation.EN_ATTENTE, null));
        LigneCotisation autreNom = LigneCotisation.builder()
                .id(99L).vehiculeId(VEHICULE).chauffeurId(NOUVEAU).dateCotisation(JOUR)
                .nomCotisation("Assurance")
                .montantDu(BigDecimal.valueOf(500))
                .statut(StatutLigneCotisation.EN_ATTENTE).build();
        when(ligneCotisationRepository.findByChauffeurIdAndDateCotisation(NOUVEAU, JOUR))
                .thenReturn(List.of(autreNom));

        useCase.executer(LIGNE_ID, NOUVEAU, MOTIF);

        verify(ligneCotisationRepository).reaffecterChauffeur(LIGNE_ID, NOUVEAU);
    }
}
