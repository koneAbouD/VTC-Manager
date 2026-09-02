package com.tmk.vtcmanager.application.usecases.reaffectation;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.reaffectation.ApercuReaffectation;
import com.tmk.vtcmanager.application.domain.reaffectation.CandidatReaffectation;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.services.IndisponibiliteSubstitutionService;
import com.tmk.vtcmanager.application.services.ReaffectationChauffeurService;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Ce que l'écran de réaffectation apprend à l'ouverture.
 *
 * <p>Deux exigences s'y jouent. Le <b>verdict</b> d'abord : chaque chauffeur
 * revient jugé, conflit compris, pour que l'écran montre l'obstacle avant le
 * choix plutôt qu'au retour du serveur. La <b>vérité des impacts</b> ensuite :
 * avant cette lecture, le client annonçait qu'une pénalité allait basculer
 * même quand il n'en existait aucune.
 */
class GetApercuReaffectationUseCaseTest {

    private static final Long LIGNE_ID = 77L;
    private static final Long VEHICULE = 5L;
    private static final Long ACTUEL = 1L;
    private static final Long LIBRE = 2L;
    private static final Long PRIS_AILLEURS = 3L;
    private static final LocalDate JOUR = LocalDate.of(2026, 4, 6);

    private LigneRecetteRepository ligneRecetteRepository;
    private LigneCotisationRepository ligneCotisationRepository;
    private LignePenaliteRepository lignePenaliteRepository;
    private ChauffeurRepository chauffeurRepository;
    private ProgrammeTravailRepository programmeTravailRepository;
    private GetApercuReaffectationUseCase useCase;

    @BeforeEach
    void setUp() {
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        chauffeurRepository = mock(ChauffeurRepository.class);
        programmeTravailRepository = mock(ProgrammeTravailRepository.class);
        ArreteCompteRepository arreteCompteRepository = mock(ArreteCompteRepository.class);
        PaiementRepository paiementRepository = mock(PaiementRepository.class);
        CloturePeriodeRepository cloturePeriodeRepository = mock(CloturePeriodeRepository.class);
        ClotureCaisseRepository clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        IndisponibiliteSubstitutionService substitution = mock(IndisponibiliteSubstitutionService.class);

        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.empty());
        when(clotureCaisseRepository.findDerniereDateClotureToutesCaisses()).thenReturn(Optional.empty());
        when(clotureCaisseRepository.findDernieresClotureParCompte()).thenReturn(Map.of());
        when(arreteCompteRepository.existeLigneValidePourDocument(any(), anyLong())).thenReturn(false);
        when(paiementRepository.existeEnCours(any(), anyLong())).thenReturn(false);
        when(lignePenaliteRepository.findByLigneRecetteId(anyLong())).thenReturn(List.of());
        when(substitution.appliquer(any(), any())).thenAnswer(inv -> inv.getArgument(0));
        when(chauffeurRepository.findAll()).thenReturn(List.of(
                chauffeur(ACTUEL, "Kouassi", "Yao"),
                chauffeur(LIBRE, "Aya", "Traoré"),
                chauffeur(PRIS_AILLEURS, "Salif", "Koné")));
        when(programmeTravailRepository.findByVehiculeId(VEHICULE)).thenReturn(Optional.empty());
        when(ligneCotisationRepository.findByDateCotisation(any())).thenReturn(List.of());

        ReaffectationChauffeurService service = new ReaffectationChauffeurService(
                new VerrouArreteService(cloturePeriodeRepository, clotureCaisseRepository),
                arreteCompteRepository, paiementRepository,
                ligneRecetteRepository, ligneCotisationRepository, lignePenaliteRepository);

        useCase = new GetApercuReaffectationUseCase(ligneRecetteRepository, ligneCotisationRepository,
                chauffeurRepository, programmeTravailRepository, substitution, service);
    }

    // ── Fixtures ────────────────────────────────────────────────────────────

    private static Chauffeur chauffeur(Long id, String prenom, String nom) {
        Chauffeur c = new Chauffeur();
        c.setId(id);
        c.setPrenom(prenom);
        c.setNom(nom);
        return c;
    }

    private LigneRecette laLigne(List<Encaissement> encaissements) {
        return LigneRecette.builder()
                .id(LIGNE_ID).vehiculeId(VEHICULE).chauffeurId(ACTUEL)
                .vehiculeImmatriculation("AB-4521-CI").dateRecette(JOUR)
                .montantAttendu(BigDecimal.valueOf(15_000))
                .montantEncaisse(BigDecimal.valueOf(10_000))
                .statut(StatutLigneRecette.PARTIELLEMENT_ENCAISSE)
                .encaissements(new ArrayList<>(encaissements))
                .build();
    }

    private static Encaissement versement(int montant, boolean annule) {
        return Encaissement.builder()
                .id(1L).ligneRecetteId(LIGNE_ID)
                .montant(BigDecimal.valueOf(montant))
                .dateEncaissement(JOUR)
                .annuleLe(annule ? LocalDateTime.now() : null)
                .build();
    }

    private void enBase(LigneRecette ligne, List<LigneRecette> journee) {
        when(ligneRecetteRepository.findById(LIGNE_ID)).thenReturn(Optional.of(ligne));
        List<LigneRecette> toutes = new ArrayList<>(journee);
        toutes.add(ligne);
        when(ligneRecetteRepository.findByDateRecette(JOUR)).thenReturn(toutes);
    }

    private static CandidatReaffectation trouver(ApercuReaffectation apercu, Long id) {
        return apercu.candidats().stream()
                .filter(c -> c.chauffeurId().equals(id))
                .findFirst().orElseThrow();
    }

    // ── Candidats ───────────────────────────────────────────────────────────

    @Test
    @DisplayName("un chauffeur pris sur un autre véhicule revient non éligible, avec sa raison")
    void conflitVisibleAvantLeChoix() {
        LigneRecette ailleurs = LigneRecette.builder()
                .id(88L).vehiculeId(9L).chauffeurId(PRIS_AILLEURS)
                .vehiculeImmatriculation("CD-1180-CI").dateRecette(JOUR)
                .statut(StatutLigneRecette.ENCAISSE).build();
        enBase(laLigne(List.of()), List.of(ailleurs));

        var candidat = trouver(useCase.pourRecette(LIGNE_ID), PRIS_AILLEURS);

        assertThat(candidat.eligible()).isFalse();
        assertThat(candidat.motif()).contains("CD-1180-CI");
    }

    @Test
    @DisplayName("un chauffeur libre est éligible, et son état du jour est dit")
    void chauffeurLibre() {
        enBase(laLigne(List.of()), List.of());

        var candidat = trouver(useCase.pourRecette(LIGNE_ID), LIBRE);

        assertThat(candidat.eligible()).isTrue();
        assertThat(candidat.motif()).contains("Aucune créance");
    }

    @Test
    @DisplayName("le chauffeur actuel ouvre la liste, marqué comme tel et sans obstacle")
    void chauffeurActuelEnTete() {
        enBase(laLigne(List.of()), List.of());

        var apercu = useCase.pourRecette(LIGNE_ID);

        assertThat(apercu.candidats().getFirst().chauffeurId()).isEqualTo(ACTUEL);
        assertThat(apercu.candidats().getFirst().actuel()).isTrue();
        assertThat(apercu.candidats().getFirst().eligible()).isTrue();
        assertThat(apercu.candidats().getFirst().motif()).isNull();
    }

    @Test
    @DisplayName("les conducteurs au programme du véhicule passent devant les autres")
    void auProgrammeDabord() {
        enBase(laLigne(List.of()), List.of());
        ProgrammeTravail programme = ProgrammeTravail.defaultForVehicule(VEHICULE);
        programme.setChauffeurs(List.of(ProgrammeChauffeur.builder()
                .chauffeur(chauffeur(LIBRE, "Aya", "Traoré"))
                .ordreAlternance(1).build()));
        when(programmeTravailRepository.findByVehiculeId(VEHICULE)).thenReturn(Optional.of(programme));

        var apercu = useCase.pourRecette(LIGNE_ID);

        assertThat(trouver(apercu, LIBRE).auProgramme()).isTrue();
        assertThat(trouver(apercu, PRIS_AILLEURS).auProgramme()).isFalse();
        // Actuel, puis au programme, puis le reste.
        assertThat(apercu.candidats().stream().map(CandidatReaffectation::chauffeurId))
                .containsExactly(ACTUEL, LIBRE, PRIS_AILLEURS);
    }

    @Test
    @DisplayName("la journée est lue une seule fois, quel que soit le nombre de candidats")
    void uneSeuleLectureDeLaJournee() {
        enBase(laLigne(List.of()), List.of());

        useCase.pourRecette(LIGNE_ID);

        verify(ligneRecetteRepository, times(1)).findByDateRecette(JOUR);
        verify(ligneCotisationRepository, times(1)).findByDateCotisation(JOUR);
    }

    // ── Impacts ─────────────────────────────────────────────────────────────

    @Test
    @DisplayName("les versements extournés ne comptent pas parmi les écritures qui suivront")
    void versementsVivantsSeulement() {
        enBase(laLigne(List.of(versement(10_000, false), versement(3_000, true))), List.of());

        var impacts = useCase.pourRecette(LIGNE_ID).impacts();

        assertThat(impacts.encaissementsRattaches()).isEqualTo(1);
        assertThat(impacts.montantCreance()).isEqualByComparingTo("15000");
        assertThat(impacts.montantEncaisse()).isEqualByComparingTo("10000");
    }

    @Test
    @DisplayName("sans pénalité adossée, l'écran n'a rien à annoncer — le défaut que la V2 corrige")
    void aucunePenaliteAAnnoncer() {
        enBase(laLigne(List.of()), List.of());

        var impacts = useCase.pourRecette(LIGNE_ID).impacts();

        assertThat(impacts.penalitesQuiSuivent()).isZero();
        assertThat(impacts.montantPenalites()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("une pénalité en attente est comptée, avec son montant")
    void penaliteQuiSuit() {
        enBase(laLigne(List.of()), List.of());
        when(lignePenaliteRepository.findByLigneRecetteId(LIGNE_ID)).thenReturn(List.of(
                LignePenalite.builder()
                        .id(300L).ligneRecetteId(LIGNE_ID).chauffeurId(ACTUEL)
                        .montant(BigDecimal.valueOf(5_000))
                        .montantEncaisse(BigDecimal.ZERO)
                        .statut(StatutLignePenalite.EN_ATTENTE)
                        .encaissements(new ArrayList<>()).build()));

        var impacts = useCase.pourRecette(LIGNE_ID).impacts();

        assertThat(impacts.penalitesQuiSuivent()).isEqualTo(1);
        assertThat(impacts.montantPenalites()).isEqualByComparingTo("5000");
    }

    @Test
    @DisplayName("côté cotisation : le dû fait la créance, et rien ne s'y adosse")
    void apercuCotisation() {
        LigneCotisation ligne = LigneCotisation.builder()
                .id(41L).vehiculeId(VEHICULE).chauffeurId(ACTUEL).dateCotisation(JOUR)
                .nomCotisation("Épargne")
                .montantDu(BigDecimal.valueOf(1_000))
                .montantEncaisse(BigDecimal.valueOf(1_000))
                .statut(StatutLigneCotisation.ENCAISSE)
                .encaissements(new ArrayList<>()).build();
        when(ligneCotisationRepository.findById(41L)).thenReturn(Optional.of(ligne));
        when(ligneCotisationRepository.findByDateCotisation(JOUR)).thenReturn(List.of(ligne));
        when(ligneRecetteRepository.findByDateRecette(JOUR)).thenReturn(List.of());

        var apercu = useCase.pourCotisation(41L);

        assertThat(apercu.impacts().montantCreance()).isEqualByComparingTo("1000");
        assertThat(apercu.impacts().penalitesQuiSuivent()).isZero();
        assertThat(trouver(apercu, LIBRE).eligible()).isTrue();
    }
}
