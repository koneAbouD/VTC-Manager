package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ModeAlternance;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Pénalité de recette non versée : elle ne se déclenche que si la recette du
 * jour est réellement restée impayée. Une recette encaissée, un véhicule
 * immobilisé ou une pénalité déjà infligée doivent tous laisser le chauffeur
 * tranquille — une double sanction pour la même faute est indéfendable.
 */
class GenererLignesPenaliteUseCaseTest {

    private static final LocalDate LUNDI = LocalDate.of(2026, 4, 6);
    private static final Long VEHICULE = 5L;
    private static final Long CHAUFFEUR_A = 1L;
    private static final Long CHAUFFEUR_B = 2L;

    private ProgrammeTravailRepository programmeTravailRepository;
    private ConditionTravailRepository conditionTravailRepository;
    private LigneRecetteRepository ligneRecetteRepository;
    private LignePenaliteRepository lignePenaliteRepository;
    private IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private GenererLignesPenaliteUseCase useCase;

    @BeforeEach
    void setUp() {
        programmeTravailRepository = mock(ProgrammeTravailRepository.class);
        conditionTravailRepository = mock(ConditionTravailRepository.class);
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        lignePenaliteRepository = mock(LignePenaliteRepository.class);
        indisponibiliteVehiculeRepository = mock(IndisponibiliteVehiculeRepository.class);

        when(indisponibiliteVehiculeRepository.isImmobiliseAt(anyLong(), any())).thenReturn(false);
        when(lignePenaliteRepository.existsDejaGeneree(anyLong(), anyLong(), any(), any()))
                .thenReturn(false);
        when(lignePenaliteRepository.save(any())).thenAnswer(inv -> {
            LignePenalite ligne = inv.getArgument(0);
            ligne.setId(700L);
            return ligne;
        });
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A)));
        condition(template(TypePenalite.RECETTE_NON_VERSEE, TypeSanction.AMENDE, 5_000d));
        recetteNonVersee(CHAUFFEUR_A);

        useCase = new GenererLignesPenaliteUseCase(programmeTravailRepository,
                conditionTravailRepository, ligneRecetteRepository, lignePenaliteRepository,
                indisponibiliteVehiculeRepository);
    }

    // ── Fixtures ────────────────────────────────────────────────────────────

    private ProgrammeTravail programme(Long... chauffeurIds) {
        List<ProgrammeChauffeur> chauffeurs = new ArrayList<>();
        int ordre = 1;
        for (Long id : chauffeurIds) {
            chauffeurs.add(ProgrammeChauffeur.builder()
                    .chauffeur(Chauffeur.builder().id(id).build())
                    .ordreAlternance(ordre++).build());
        }
        return ProgrammeTravail.builder()
                .id(1L).vehiculeId(VEHICULE)
                .nombreChauffeursAutorises(chauffeurIds.length)
                .joursTravailSemaine(EnumSet.allOf(JourSemaine.class))
                .joursAlternanceSemaine(EnumSet.allOf(JourSemaine.class))
                .chauffeurs(chauffeurs)
                .build();
    }

    private PenaliteTemplate template(TypePenalite type, TypeSanction sanction, Double montant) {
        PenaliteTemplate template = new PenaliteTemplate();
        template.setId(3L);
        template.setTypePenalite(type.name());
        template.setTypeSanction(sanction.name());
        template.setMontant(montant);
        template.setDureeSanctionSecondes(30);
        template.setDureeImmobilisationMinutes(60);
        return template;
    }

    private void condition(PenaliteTemplate... penalites) {
        ConditionTravail condition = new ConditionTravail();
        condition.setId(1L);
        condition.setPenalites(penalites == null ? null : List.of(penalites));
        when(conditionTravailRepository.findByVehiculeId(VEHICULE)).thenReturn(Optional.of(condition));
    }

    private void recette(Long chauffeurId, StatutLigneRecette statut) {
        when(ligneRecetteRepository.findByVehiculeIdAndChauffeurIdAndDateRecette(
                VEHICULE, chauffeurId, LUNDI))
                .thenReturn(Optional.of(LigneRecette.builder()
                        .id(100L + chauffeurId).vehiculeId(VEHICULE).chauffeurId(chauffeurId)
                        .dateRecette(LUNDI).montantAttendu(BigDecimal.valueOf(15_000))
                        .statut(statut).build()));
    }

    private void recetteNonVersee(Long chauffeurId) {
        recette(chauffeurId, StatutLigneRecette.EN_ATTENTE);
    }

    // ── Cas nominal ─────────────────────────────────────────────────────────

    private List<LignePenalite> useCaseExecuter() {
        return useCase.executerPourRecettesNonVersees(LUNDI);
    }

    @Test
    @DisplayName("Une recette restée en attente déclenche la pénalité configurée")
    void penalite_generee() {
        List<LignePenalite> generees = useCaseExecuter();

        assertThat(generees).singleElement().satisfies(p -> {
            assertThat(p.getVehiculeId()).isEqualTo(VEHICULE);
            assertThat(p.getChauffeurId()).isEqualTo(CHAUFFEUR_A);
            assertThat(p.getTypePenalite()).isEqualTo(TypePenalite.RECETTE_NON_VERSEE);
            assertThat(p.getTypeSanction()).isEqualTo(TypeSanction.AMENDE);
            assertThat(p.getMontant()).isEqualByComparingTo("5000");
            assertThat(p.getStatut()).isEqualTo(StatutLignePenalite.EN_ATTENTE);
            assertThat(p.getDateFaute()).isEqualTo(LUNDI);
            assertThat(p.getMontantEncaisse()).isEqualByComparingTo("0");
        });
    }

    @Test
    @DisplayName("La pénalité pointe la ligne de recette fautive et la date de génération")
    void penalite_reliee_a_la_recette() {
        LignePenalite penalite = useCaseExecuter().get(0);

        assertThat(penalite.getLigneRecetteId()).isEqualTo(101L);
        assertThat(penalite.getPenaliteTemplateId()).isEqualTo(3L);
        assertThat(penalite.getDateGeneration()).isEqualTo(LocalDate.now());
    }

    @Test
    @DisplayName("Une recette partiellement encaissée reste fautive")
    void recette_partielle_penalisee() {
        recette(CHAUFFEUR_A, StatutLigneRecette.PARTIELLEMENT_ENCAISSE);

        assertThat(useCaseExecuter()).hasSize(1);
    }

    // ── Cas où aucune pénalité n'est due ────────────────────────────────────

    @ParameterizedTest(name = "recette {0} → aucune pénalité")
    @EnumSource(value = StatutLigneRecette.class, names = {"ENCAISSE", "ANNULEE"})
    @DisplayName("Une recette encaissée ou annulée ne déclenche aucune pénalité")
    void recette_soldee_ou_annulee(StatutLigneRecette statut) {
        recette(CHAUFFEUR_A, statut);

        assertThat(useCaseExecuter()).isEmpty();
        verify(lignePenaliteRepository, never()).save(any());
    }

    @Test
    @DisplayName("Sans ligne de recette pour ce jour, il n'y a pas de faute")
    void aucune_recette_du_jour() {
        when(ligneRecetteRepository.findByVehiculeIdAndChauffeurIdAndDateRecette(
                VEHICULE, CHAUFFEUR_A, LUNDI)).thenReturn(Optional.empty());

        assertThat(useCaseExecuter()).isEmpty();
    }

    @Test
    @DisplayName("Un véhicule immobilisé ne devait aucune recette, donc aucune pénalité")
    void vehicule_immobilise() {
        when(indisponibiliteVehiculeRepository.isImmobiliseAt(VEHICULE, LUNDI)).thenReturn(true);

        assertThat(useCaseExecuter()).isEmpty();
        verify(ligneRecetteRepository, never())
                .findByVehiculeIdAndChauffeurIdAndDateRecette(anyLong(), anyLong(), any());
    }

    @Test
    @DisplayName("Une pénalité déjà infligée pour cette faute n'est pas doublée")
    void penalite_deja_generee() {
        when(lignePenaliteRepository.existsDejaGeneree(
                VEHICULE, CHAUFFEUR_A, TypePenalite.RECETTE_NON_VERSEE, LUNDI)).thenReturn(true);

        assertThat(useCaseExecuter()).isEmpty();
        verify(lignePenaliteRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un véhicule sans condition de travail est ignoré")
    void sans_condition() {
        when(conditionTravailRepository.findByVehiculeId(VEHICULE)).thenReturn(Optional.empty());

        assertThat(useCaseExecuter()).isEmpty();
    }

    @Test
    @DisplayName("Une condition sans liste de pénalités est ignorée")
    void condition_sans_penalites() {
        condition((PenaliteTemplate[]) null);

        assertThat(useCaseExecuter()).isEmpty();
    }

    @Test
    @DisplayName("Une condition sans pénalité de recette non versée est ignorée")
    void autre_type_de_penalite_seulement() {
        condition(template(TypePenalite.EXCES_VITESSE, TypeSanction.BUZZER, null));

        assertThat(useCaseExecuter()).isEmpty();
    }

    @Test
    @DisplayName("Un programme sans chauffeur ne génère rien")
    void programme_sans_chauffeur() {
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme()));

        assertThat(useCaseExecuter()).isEmpty();
    }

    // ── Sanctions non monétaires et alternance ──────────────────────────────

    @Test
    @DisplayName("Une sanction sans montant vaut zéro, pas null")
    void sanction_sans_montant() {
        condition(template(TypePenalite.RECETTE_NON_VERSEE, TypeSanction.BUZZER, null));

        assertThat(useCaseExecuter()).singleElement().satisfies(p -> {
            assertThat(p.getMontant()).isEqualByComparingTo("0");
            assertThat(p.getTypeSanction()).isEqualTo(TypeSanction.BUZZER);
            assertThat(p.getDureeSanctionSecondes()).isEqualTo(30);
        });
    }

    @Test
    @DisplayName("Une sanction d'immobilisation reporte sa durée sur la ligne")
    void sanction_immobilisation() {
        condition(template(TypePenalite.RECETTE_NON_VERSEE, TypeSanction.IMMOBILISATION, null));

        assertThat(useCaseExecuter()).singleElement()
                .extracting(LignePenalite::getDureeImmobilisationMinutes).isEqualTo(60);
    }

    @Test
    @DisplayName("Sur un jour partagé, chaque chauffeur en défaut est pénalisé")
    void jour_partage_deux_penalites() {
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A, CHAUFFEUR_B)));
        recetteNonVersee(CHAUFFEUR_B);

        assertThat(useCaseExecuter()).extracting(LignePenalite::getChauffeurId)
                .containsExactly(CHAUFFEUR_A, CHAUFFEUR_B);
    }

    @Test
    @DisplayName("Sur un jour partagé, seul le chauffeur en défaut est pénalisé")
    void jour_partage_un_seul_fautif() {
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A, CHAUFFEUR_B)));
        recette(CHAUFFEUR_B, StatutLigneRecette.ENCAISSE);

        assertThat(useCaseExecuter()).extracting(LignePenalite::getChauffeurId)
                .containsExactly(CHAUFFEUR_A);
    }

    @Test
    @DisplayName("En alternance automatique hors jour partagé, seul le conducteur du jour est pénalisé")
    void alternance_automatique() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A, CHAUFFEUR_B);
        programme.setJoursAlternanceSemaine(EnumSet.noneOf(JourSemaine.class));
        programme.setModeAlternance(ModeAlternance.AUTOMATIQUE);
        programme.setJoursAlternance(1);
        // Départ un dimanche : le lundi est la 2e période, donc au chauffeur 2.
        programme.setDateDebutAlternance(LUNDI.minusDays(1));
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));
        recetteNonVersee(CHAUFFEUR_B);

        assertThat(useCaseExecuter()).extracting(LignePenalite::getChauffeurId)
                .containsExactly(CHAUFFEUR_B);
    }

    @Test
    @DisplayName("Un parc vide ne produit rien")
    void parc_vide() {
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of());

        assertThat(useCaseExecuter()).isEmpty();
    }
}
