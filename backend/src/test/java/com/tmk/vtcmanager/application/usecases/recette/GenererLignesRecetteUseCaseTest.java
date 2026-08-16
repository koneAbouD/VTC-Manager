package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.JourFerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.services.IndisponibiliteSubstitutionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Génération quotidienne des recettes dues. Le use case porte l'essentiel des
 * règles d'exploitation : jour de salaire, jour férié, véhicule immobilisé,
 * substitution d'un chauffeur en congé, et surtout les garde-fous contre les
 * doublons quand le programme est modifié après coup.
 *
 * <p>Un doublon ici se traduit par une créance réclamée deux fois à un
 * chauffeur : c'est le défaut le plus coûteux du module.
 */
class GenererLignesRecetteUseCaseTest {

    /** Un lundi, pour raisonner sur les jours de la semaine sans ambiguïté. */
    private static final LocalDate LUNDI = LocalDate.of(2026, 4, 6);
    private static final Long VEHICULE = 5L;
    private static final Long CHAUFFEUR_A = 1L;
    private static final Long CHAUFFEUR_B = 2L;

    private ProgrammeTravailRepository programmeTravailRepository;
    private ConfigurationRecetteRepository configurationRecetteRepository;
    private LigneRecetteRepository ligneRecetteRepository;
    private IndisponibiliteSubstitutionService substitutionService;
    private IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private JourFerieRepository jourFerieRepository;
    private GenererLignesRecetteUseCase useCase;

    @BeforeEach
    void setUp() {
        programmeTravailRepository = mock(ProgrammeTravailRepository.class);
        configurationRecetteRepository = mock(ConfigurationRecetteRepository.class);
        ligneRecetteRepository = mock(LigneRecetteRepository.class);
        substitutionService = mock(IndisponibiliteSubstitutionService.class);
        indisponibiliteVehiculeRepository = mock(IndisponibiliteVehiculeRepository.class);
        jourFerieRepository = mock(JourFerieRepository.class);

        // Cas nominal : véhicule disponible, jour ordinaire, aucune substitution.
        when(indisponibiliteVehiculeRepository.isImmobiliseAt(anyLong(), any())).thenReturn(false);
        when(jourFerieRepository.existsByDate(any())).thenReturn(false);
        when(substitutionService.appliquer(any(), any())).thenAnswer(inv -> inv.getArgument(0));
        when(ligneRecetteRepository.findByVehiculeIdAndDateRecette(anyLong(), any()))
                .thenReturn(List.of());
        when(ligneRecetteRepository.save(any())).thenAnswer(inv -> {
            LigneRecette ligne = inv.getArgument(0);
            if (ligne.getId() == null) ligne.setId(1_000L + ligne.getChauffeurId());
            return ligne;
        });
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A)));
        configuration(config(TypeRecetteConfiguration.MONTANT_FIXE, 15_000));

        useCase = new GenererLignesRecetteUseCase(programmeTravailRepository,
                configurationRecetteRepository, ligneRecetteRepository, substitutionService,
                indisponibiliteVehiculeRepository, jourFerieRepository);
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

    private ConfigurationRecette config(TypeRecetteConfiguration type, Integer objectif) {
        return ConfigurationRecette.builder()
                .id(1L).vehiculeId(VEHICULE).typeRecette(type)
                .montantObjectifParChauffeur(objectif == null ? null : BigDecimal.valueOf(objectif))
                .cotisations(new ArrayList<>())
                .build();
    }

    private void configuration(ConfigurationRecette config) {
        when(configurationRecetteRepository.findByVehiculeId(VEHICULE))
                .thenReturn(Optional.ofNullable(config));
    }

    private LigneRecette ligne(Long id, Long chauffeurId, StatutLigneRecette statut, int encaisse) {
        return LigneRecette.builder()
                .id(id).vehiculeId(VEHICULE).chauffeurId(chauffeurId).dateRecette(LUNDI)
                .montantAttendu(BigDecimal.valueOf(15_000))
                .montantEncaisse(BigDecimal.valueOf(encaisse))
                .statut(statut).encaissements(new ArrayList<>())
                .build();
    }

    private void lignesExistantes(LigneRecette... lignes) {
        when(ligneRecetteRepository.findByVehiculeIdAndDateRecette(VEHICULE, LUNDI))
                .thenReturn(new ArrayList<>(List.of(lignes)));
    }

    // ── Cas nominal ─────────────────────────────────────────────────────────

    @Test
    @DisplayName("Une ligne par chauffeur actif, au montant fixe de la configuration")
    void ligne_par_chauffeur() {
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A, CHAUFFEUR_B)));

        List<LigneRecette> generees = useCase.executer(LUNDI);

        assertThat(generees).hasSize(2);
        assertThat(generees).extracting(LigneRecette::getChauffeurId)
                .containsExactly(CHAUFFEUR_A, CHAUFFEUR_B);
        assertThat(generees).allSatisfy(l -> {
            assertThat(l.getMontantAttendu()).isEqualByComparingTo("15000");
            assertThat(l.getStatut()).isEqualTo(StatutLigneRecette.EN_ATTENTE);
            assertThat(l.getDateRecette()).isEqualTo(LUNDI);
        });
    }

    @Test
    @DisplayName("En recette réelle, aucun montant attendu n'est fixé d'avance")
    void montant_reel_sans_objectif() {
        configuration(config(TypeRecetteConfiguration.MONTANT_REEL, 15_000));

        assertThat(useCase.executer(LUNDI)).singleElement()
                .extracting(LigneRecette::getMontantAttendu).isNull();
    }

    // ── Cas où rien n'est dû ────────────────────────────────────────────────

    @Test
    @DisplayName("Un véhicule immobilisé ne doit aucune recette")
    void vehicule_immobilise() {
        when(indisponibiliteVehiculeRepository.isImmobiliseAt(VEHICULE, LUNDI)).thenReturn(true);

        assertThat(useCase.executer(LUNDI)).isEmpty();
        verify(ligneRecetteRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un programme sans chauffeur affecté ne génère rien")
    void programme_sans_chauffeur() {
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme()));

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Un véhicule sans configuration de recette est ignoré")
    void sans_configuration() {
        configuration(null);

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Un jour non travaillé par le véhicule ne génère rien")
    void jour_non_travaille() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setJoursTravailSemaine(EnumSet.of(JourSemaine.SAMEDI, JourSemaine.DIMANCHE));
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    // ── Jour de salaire ─────────────────────────────────────────────────────

    @Test
    @DisplayName("Le jour de salaire sans montant spécial ne doit aucune recette")
    void jour_salaire_sans_montant() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setJourSalaireActif(true);
        programme.setJourSalaire(JourSemaine.LUNDI);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        assertThat(useCase.executer(LUNDI)).isEmpty();
        verify(ligneRecetteRepository, never()).save(any());
    }

    @Test
    @DisplayName("Le jour de salaire applique le montant spécial quand il est configuré")
    void jour_salaire_avec_montant() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setJourSalaireActif(true);
        programme.setJourSalaire(JourSemaine.LUNDI);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        ConfigurationRecette config = config(TypeRecetteConfiguration.MONTANT_FIXE, 15_000);
        config.setMontantJourSalaire(BigDecimal.valueOf(5_000));
        configuration(config);

        assertThat(useCase.executer(LUNDI)).singleElement()
                .extracting(LigneRecette::getMontantAttendu)
                .isEqualTo(BigDecimal.valueOf(5_000));
    }

    @Test
    @DisplayName("Un jour de salaire purge les lignes en attente déjà générées")
    void jour_salaire_purge_les_lignes_en_attente() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setJourSalaireActif(true);
        programme.setJourSalaire(JourSemaine.LUNDI);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));
        lignesExistantes(ligne(50L, CHAUFFEUR_A, StatutLigneRecette.EN_ATTENTE, 0));

        useCase.executer(LUNDI);

        // La journée a d'abord été générée comme ordinaire, puis le jour de
        // salaire a été activé : la ligne devenue indue doit disparaître.
        verify(ligneRecetteRepository).deleteById(50L);
    }

    @Test
    @DisplayName("Un jour de salaire ne purge pas une ligne déjà encaissée")
    void jour_salaire_preserve_les_encaissements() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setJourSalaireActif(true);
        programme.setJourSalaire(JourSemaine.LUNDI);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));
        lignesExistantes(ligne(50L, CHAUFFEUR_A, StatutLigneRecette.ENCAISSE, 15_000));

        useCase.executer(LUNDI);

        verify(ligneRecetteRepository, never()).deleteById(anyLong());
    }

    // ── Jour férié ──────────────────────────────────────────────────────────

    @Test
    @DisplayName("Un jour férié applique le montant férié quand l'option est active")
    void jour_ferie_avec_montant() {
        when(jourFerieRepository.existsByDate(LUNDI)).thenReturn(true);
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setFeriesActif(true);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        ConfigurationRecette config = config(TypeRecetteConfiguration.MONTANT_FIXE, 15_000);
        config.setMontantJourFerie(BigDecimal.valueOf(8_000));
        configuration(config);

        assertThat(useCase.executer(LUNDI)).singleElement()
                .extracting(LigneRecette::getMontantAttendu)
                .isEqualTo(BigDecimal.valueOf(8_000));
    }

    @Test
    @DisplayName("Un jour férié sans montant configuré ne doit aucune recette")
    void jour_ferie_sans_montant() {
        when(jourFerieRepository.existsByDate(LUNDI)).thenReturn(true);
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setFeriesActif(true);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Sans option « fériés considérés », un jour férié reste un jour ordinaire")
    void jour_ferie_option_inactive() {
        when(jourFerieRepository.existsByDate(LUNDI)).thenReturn(true);
        ConfigurationRecette config = config(TypeRecetteConfiguration.MONTANT_FIXE, 15_000);
        config.setMontantJourFerie(BigDecimal.valueOf(8_000));
        configuration(config);

        // feriesActif reste faux sur le programme par défaut.
        assertThat(useCase.executer(LUNDI)).singleElement()
                .extracting(LigneRecette::getMontantAttendu).isEqualTo(BigDecimal.valueOf(15_000));
    }

    @Test
    @DisplayName("Quand jour de salaire et jour férié coïncident, le jour de salaire prime")
    void jour_salaire_prime_sur_ferie() {
        when(jourFerieRepository.existsByDate(LUNDI)).thenReturn(true);
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setFeriesActif(true);
        programme.setJourSalaireActif(true);
        programme.setJourSalaire(JourSemaine.LUNDI);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        ConfigurationRecette config = config(TypeRecetteConfiguration.MONTANT_FIXE, 15_000);
        config.setMontantJourSalaire(BigDecimal.valueOf(5_000));
        config.setMontantJourFerie(BigDecimal.valueOf(8_000));
        configuration(config);

        assertThat(useCase.executer(LUNDI)).singleElement()
                .extracting(LigneRecette::getMontantAttendu)
                .isEqualTo(BigDecimal.valueOf(5_000));
    }

    // ── Reprises et garde-fous ──────────────────────────────────────────────

    @Test
    @DisplayName("Une ligne existante du même chauffeur est mise à jour, pas dupliquée")
    void ligne_existante_mise_a_jour() {
        LigneRecette existante = ligne(50L, CHAUFFEUR_A, StatutLigneRecette.EN_ATTENTE, 0);
        existante.setMontantAttendu(BigDecimal.valueOf(12_000));
        lignesExistantes(existante);

        List<LigneRecette> generees = useCase.executer(LUNDI);

        assertThat(generees).singleElement().satisfies(l -> {
            assertThat(l.getId()).isEqualTo(50L);
            assertThat(l.getMontantAttendu()).isEqualByComparingTo("15000");
        });
    }

    @Test
    @DisplayName("L'alternance corrigée avant tout versement remplace la ligne du jour")
    void alternance_corrigee_avant_versement() {
        lignesExistantes(ligne(50L, CHAUFFEUR_B, StatutLigneRecette.EN_ATTENTE, 0));

        // Le programme n'a plus que le chauffeur A. La ligne de B, en attente et
        // sans versement, est purgée ; la recette du jour est portée par A.
        List<LigneRecette> generees = useCase.executer(LUNDI);

        verify(ligneRecetteRepository).deleteById(50L);
        assertThat(generees).singleElement().satisfies(l -> {
            assertThat(l.getChauffeurId()).isEqualTo(CHAUFFEUR_A);
            assertThat(l.getId()).isNotEqualTo(50L);
        });
    }

    @Test
    @DisplayName("Chaque chauffeur d'un jour partagé garde sa propre ligne")
    void jour_partage_une_ligne_par_chauffeur() {
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A, CHAUFFEUR_B)));
        lignesExistantes(
                ligne(50L, CHAUFFEUR_A, StatutLigneRecette.EN_ATTENTE, 0),
                ligne(51L, CHAUFFEUR_B, StatutLigneRecette.EN_ATTENTE, 0));

        List<LigneRecette> generees = useCase.executer(LUNDI);

        assertThat(generees).hasSize(2);
        assertThat(generees).extracting(LigneRecette::getId).containsExactly(50L, 51L);
        assertThat(generees).extracting(LigneRecette::getChauffeurId)
                .containsExactly(CHAUFFEUR_A, CHAUFFEUR_B);
        verify(ligneRecetteRepository, never()).deleteById(anyLong());
    }

    @Test
    @DisplayName("Un jour partagé où une seule ligne préexiste ne la vole pas à son chauffeur")
    void jour_partage_ligne_preexistante_non_volee() {
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A, CHAUFFEUR_B)));
        // Seul A a déjà sa ligne (B n'a pas encore été généré) : la ligne de A
        // ne doit pas lui être retirée pour servir B, sinon A ne doit plus rien.
        lignesExistantes(ligne(50L, CHAUFFEUR_A, StatutLigneRecette.EN_ATTENTE, 0));

        List<LigneRecette> generees = useCase.executer(LUNDI);

        assertThat(generees).hasSize(2);
        assertThat(generees).extracting(LigneRecette::getChauffeurId)
                .containsExactly(CHAUFFEUR_A, CHAUFFEUR_B);
        assertThat(generees).extracting(LigneRecette::getId).doesNotHaveDuplicates();
        assertThat(generees).first()
                .extracting(LigneRecette::getId).isEqualTo(50L);
        verify(ligneRecetteRepository, never()).deleteById(anyLong());
    }

    @Test
    @DisplayName("Une ligne annulée n'est jamais réutilisée : une nouvelle ligne est créée")
    void ligne_annulee_non_reutilisee() {
        lignesExistantes(ligne(50L, CHAUFFEUR_A, StatutLigneRecette.ANNULEE, 0));

        assertThat(useCase.executer(LUNDI)).singleElement().satisfies(l -> {
            assertThat(l.getId()).isNotEqualTo(50L);
            assertThat(l.getStatut()).isEqualTo(StatutLigneRecette.EN_ATTENTE);
        });
    }

    @Test
    @DisplayName("La ligne en attente d'un chauffeur retiré du programme est supprimée")
    void ligne_obsolete_supprimee() {
        // Deux lignes préexistantes ; seul A conduit désormais. La ligne de B,
        // en attente et sans versement, n'a plus lieu d'être.
        lignesExistantes(
                ligne(50L, CHAUFFEUR_A, StatutLigneRecette.EN_ATTENTE, 0),
                ligne(51L, CHAUFFEUR_B, StatutLigneRecette.EN_ATTENTE, 0));

        useCase.executer(LUNDI);

        verify(ligneRecetteRepository).deleteById(51L);
        verify(ligneRecetteRepository, never()).deleteById(50L);
    }

    @Test
    @DisplayName("Un chauffeur retiré qui a déjà encaissé bloque la régénération du jour")
    void anti_doublon_apres_encaissement() {
        // Inversion rétroactive de l'alternance : B a conduit et versé, puis le
        // programme a été corrigé au profit de A. Générer une ligne pour A
        // réclamerait deux fois la recette du jour.
        lignesExistantes(ligne(51L, CHAUFFEUR_B, StatutLigneRecette.ENCAISSE, 15_000));

        assertThat(useCase.executer(LUNDI)).isEmpty();
        verify(ligneRecetteRepository, never()).save(any());
        verify(ligneRecetteRepository, never()).deleteById(anyLong());
    }

    @Test
    @DisplayName("Un encaissement partiel d'un chauffeur retiré bloque aussi la régénération")
    void anti_doublon_encaissement_partiel() {
        lignesExistantes(ligne(51L, CHAUFFEUR_B, StatutLigneRecette.EN_ATTENTE, 5_000));

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Une ligne annulée d'un chauffeur retiré ne bloque pas la régénération")
    void ligne_annulee_ne_bloque_pas() {
        lignesExistantes(ligne(51L, CHAUFFEUR_B, StatutLigneRecette.ANNULEE, 15_000));

        assertThat(useCase.executer(LUNDI)).singleElement()
                .extracting(LigneRecette::getChauffeurId).isEqualTo(CHAUFFEUR_A);
    }

    @Test
    @DisplayName("La recette est due par le remplaçant du chauffeur en congé")
    void substitution_du_chauffeur_indisponible() {
        when(substitutionService.appliquer(List.of(CHAUFFEUR_A), LUNDI)).thenReturn(List.of(9L));

        assertThat(useCase.executer(LUNDI)).singleElement()
                .extracting(LigneRecette::getChauffeurId).isEqualTo(9L);
    }

    @Test
    @DisplayName("Le caractère férié de la date n'est interrogé qu'une fois pour tout le parc")
    void ferie_interroge_une_seule_fois() {
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A), programme(CHAUFFEUR_B)));

        useCase.executer(LUNDI);

        verify(jourFerieRepository).existsByDate(LUNDI);
    }

    @Test
    @DisplayName("Un parc vide ne produit rien")
    void parc_vide() {
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of());

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Les jours de travail vides valent « tous les jours »")
    void jours_travail_vides() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setJoursTravailSemaine(Set.of());
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        assertThat(useCase.executer(LUNDI)).hasSize(1);
    }
}
