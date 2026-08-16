package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.CotisationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Génération quotidienne des cotisations dues. Deux différences de fond avec la
 * recette : les cotisations restent dues un jour férié (seule la recette change
 * de montant), et elles disparaissent le jour de salaire — ce jour-là le
 * chauffeur roule pour son propre compte.
 */
class GenererLignesCotisationUseCaseTest {

    private static final LocalDate LUNDI = LocalDate.of(2026, 4, 6);
    private static final Long VEHICULE = 5L;
    private static final Long CHAUFFEUR_A = 1L;
    private static final Long CHAUFFEUR_B = 2L;

    private ProgrammeTravailRepository programmeTravailRepository;
    private ConfigurationRecetteRepository configurationRecetteRepository;
    private LigneCotisationRepository ligneCotisationRepository;
    private IndisponibiliteSubstitutionService substitutionService;
    private IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private GenererLignesCotisationUseCase useCase;

    @BeforeEach
    void setUp() {
        programmeTravailRepository = mock(ProgrammeTravailRepository.class);
        configurationRecetteRepository = mock(ConfigurationRecetteRepository.class);
        ligneCotisationRepository = mock(LigneCotisationRepository.class);
        substitutionService = mock(IndisponibiliteSubstitutionService.class);
        indisponibiliteVehiculeRepository = mock(IndisponibiliteVehiculeRepository.class);

        when(indisponibiliteVehiculeRepository.isImmobiliseAt(anyLong(), any())).thenReturn(false);
        when(substitutionService.appliquer(any(), any())).thenAnswer(inv -> inv.getArgument(0));
        when(ligneCotisationRepository.findByVehiculeIdAndDateCotisation(anyLong(), any()))
                .thenReturn(List.of());
        when(ligneCotisationRepository.save(any())).thenAnswer(inv -> {
            LigneCotisation ligne = inv.getArgument(0);
            if (ligne.getId() == null) ligne.setId(900L);
            return ligne;
        });
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A)));
        configuration(cotisation("Épargne", 1_000), cotisation("Assurance", 500));

        useCase = new GenererLignesCotisationUseCase(programmeTravailRepository,
                configurationRecetteRepository, ligneCotisationRepository, substitutionService,
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

    private CotisationRecette cotisation(String nom, int montant) {
        return CotisationRecette.builder().nom(nom).montant(BigDecimal.valueOf(montant)).build();
    }

    private void configuration(CotisationRecette... cotisations) {
        when(configurationRecetteRepository.findByVehiculeId(VEHICULE))
                .thenReturn(Optional.of(ConfigurationRecette.builder()
                        .id(1L).vehiculeId(VEHICULE)
                        .typeRecette(TypeRecetteConfiguration.MONTANT_FIXE)
                        .cotisations(new ArrayList<>(List.of(cotisations)))
                        .build()));
    }

    private LigneCotisation ligne(Long id, Long chauffeurId, String nom,
                                  StatutLigneCotisation statut, int encaisse) {
        return LigneCotisation.builder()
                .id(id).vehiculeId(VEHICULE).chauffeurId(chauffeurId).dateCotisation(LUNDI)
                .nomCotisation(LigneCotisation.normaliserNom(nom))
                .montantDu(BigDecimal.valueOf(1_000))
                .montantEncaisse(BigDecimal.valueOf(encaisse))
                .statut(statut).encaissements(new ArrayList<>())
                .build();
    }

    private void lignesExistantes(LigneCotisation... lignes) {
        when(ligneCotisationRepository.findByVehiculeIdAndDateCotisation(VEHICULE, LUNDI))
                .thenReturn(new ArrayList<>(List.of(lignes)));
    }

    // ── Cas nominal ─────────────────────────────────────────────────────────

    @Test
    @DisplayName("Une ligne par cotisation configurée et par chauffeur actif")
    void une_ligne_par_cotisation() {
        when(programmeTravailRepository.findAllWithChauffeurs())
                .thenReturn(List.of(programme(CHAUFFEUR_A, CHAUFFEUR_B)));

        List<LigneCotisation> generees = useCase.executer(LUNDI);

        assertThat(generees).hasSize(4);
        assertThat(generees).extracting(LigneCotisation::getChauffeurId)
                .containsExactly(CHAUFFEUR_A, CHAUFFEUR_A, CHAUFFEUR_B, CHAUFFEUR_B);
        assertThat(generees).allSatisfy(l -> {
            assertThat(l.getStatut()).isEqualTo(StatutLigneCotisation.EN_ATTENTE);
            assertThat(l.getDateCotisation()).isEqualTo(LUNDI);
            assertThat(l.getMontantEncaisse()).isEqualByComparingTo("0");
        });
    }

    @Test
    @DisplayName("Le montant dû est celui de la cotisation configurée")
    void montants_repris_de_la_configuration() {
        List<LigneCotisation> generees = useCase.executer(LUNDI);

        assertThat(generees).extracting(LigneCotisation::getMontantDu)
                .containsExactly(BigDecimal.valueOf(1_000), BigDecimal.valueOf(500));
    }

    // ── Cas où rien n'est dû ────────────────────────────────────────────────

    @Test
    @DisplayName("Un véhicule immobilisé ne doit aucune cotisation")
    void vehicule_immobilise() {
        when(indisponibiliteVehiculeRepository.isImmobiliseAt(VEHICULE, LUNDI)).thenReturn(true);

        assertThat(useCase.executer(LUNDI)).isEmpty();
        verify(ligneCotisationRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un véhicule sans cotisation configurée ne génère rien")
    void aucune_cotisation_configuree() {
        configuration();

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Un véhicule sans configuration de recette est ignoré")
    void sans_configuration() {
        when(configurationRecetteRepository.findByVehiculeId(VEHICULE)).thenReturn(Optional.empty());

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Un jour non travaillé ne génère aucune cotisation")
    void jour_non_travaille() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setJoursTravailSemaine(EnumSet.of(JourSemaine.DIMANCHE));
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    @Test
    @DisplayName("Un programme sans chauffeur ne génère rien")
    void programme_sans_chauffeur() {
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme()));

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }

    // ── Jour de salaire et jour férié ───────────────────────────────────────

    @Test
    @DisplayName("Le jour de salaire ne doit aucune cotisation")
    void jour_salaire_aucune_cotisation() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setJourSalaireActif(true);
        programme.setJourSalaire(JourSemaine.LUNDI);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        assertThat(useCase.executer(LUNDI)).isEmpty();
        verify(ligneCotisationRepository, never()).save(any());
    }

    @Test
    @DisplayName("Le jour de salaire purge les cotisations en attente déjà générées")
    void jour_salaire_purge() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setJourSalaireActif(true);
        programme.setJourSalaire(JourSemaine.LUNDI);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));
        lignesExistantes(
                ligne(60L, CHAUFFEUR_A, "Épargne", StatutLigneCotisation.EN_ATTENTE, 0),
                ligne(61L, CHAUFFEUR_A, "Assurance", StatutLigneCotisation.ENCAISSE, 500));

        useCase.executer(LUNDI);

        verify(ligneCotisationRepository).deleteById(60L);
        // La cotisation déjà encaissée reste : le versement a bien eu lieu.
        verify(ligneCotisationRepository, never()).deleteById(61L);
    }

    @Test
    @DisplayName("Les cotisations restent dues un jour férié, contrairement à la recette")
    void jour_ferie_cotisations_dues() {
        ProgrammeTravail programme = programme(CHAUFFEUR_A);
        programme.setFeriesActif(true);
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of(programme));

        // Le use case n'interroge même pas le calendrier des fériés : un jour
        // férié est un jour de cotisation ordinaire.
        assertThat(useCase.executer(LUNDI)).hasSize(2);
    }

    // ── Reprises et garde-fous ──────────────────────────────────────────────

    @Test
    @DisplayName("Une cotisation déjà générée est mise à jour, pas dupliquée")
    void cotisation_existante_mise_a_jour() {
        LigneCotisation existante = ligne(60L, CHAUFFEUR_A, "Épargne",
                StatutLigneCotisation.EN_ATTENTE, 0);
        existante.setMontantDu(BigDecimal.valueOf(700));
        lignesExistantes(existante);

        List<LigneCotisation> generees = useCase.executer(LUNDI);

        assertThat(generees).hasSize(2);
        assertThat(generees.get(0).getId()).isEqualTo(60L);
        assertThat(generees.get(0).getMontantDu()).isEqualByComparingTo("1000");
    }

    @Test
    @DisplayName("Une cotisation annulée conserve son montant d'origine")
    void cotisation_annulee_figee() {
        LigneCotisation annulee = ligne(60L, CHAUFFEUR_A, "Épargne",
                StatutLigneCotisation.ANNULEE, 0);
        annulee.setMontantDu(BigDecimal.valueOf(700));
        lignesExistantes(annulee);

        useCase.executer(LUNDI);

        assertThat(annulee.getMontantDu()).isEqualByComparingTo("700");
    }

    @Test
    @DisplayName("Une cotisation retirée de la configuration est supprimée")
    void cotisation_obsolete_supprimee() {
        lignesExistantes(ligne(60L, CHAUFFEUR_A, "Lavage", StatutLigneCotisation.EN_ATTENTE, 0));

        useCase.executer(LUNDI);

        verify(ligneCotisationRepository).deleteById(60L);
    }

    @Test
    @DisplayName("Une cotisation retirée mais déjà encaissée n'est pas supprimée")
    void cotisation_obsolete_encaissee_conservee() {
        lignesExistantes(ligne(60L, CHAUFFEUR_A, "Lavage", StatutLigneCotisation.ENCAISSE, 1_000));

        useCase.executer(LUNDI);

        verify(ligneCotisationRepository, never()).deleteById(anyLong());
    }

    @Test
    @DisplayName("Un chauffeur retiré qui a déjà cotisé bloque la régénération du jour")
    void anti_doublon_apres_encaissement() {
        lignesExistantes(ligne(61L, CHAUFFEUR_B, "Épargne", StatutLigneCotisation.ENCAISSE, 1_000));

        assertThat(useCase.executer(LUNDI)).isEmpty();
        verify(ligneCotisationRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une cotisation annulée d'un chauffeur retiré ne bloque pas la régénération")
    void ligne_annulee_ne_bloque_pas() {
        lignesExistantes(ligne(61L, CHAUFFEUR_B, "Épargne", StatutLigneCotisation.ANNULEE, 1_000));

        assertThat(useCase.executer(LUNDI)).hasSize(2);
    }

    @Test
    @DisplayName("Les cotisations sont dues par le remplaçant du chauffeur en congé")
    void substitution_appliquee() {
        when(substitutionService.appliquer(List.of(CHAUFFEUR_A), LUNDI)).thenReturn(List.of(9L));

        assertThat(useCase.executer(LUNDI)).extracting(LigneCotisation::getChauffeurId)
                .containsOnly(9L);
    }

    @Test
    @DisplayName("Le nom de la cotisation est normalisé à la création")
    void nom_normalise() {
        configuration(cotisation("  Épargne  ", 1_000));

        assertThat(useCase.executer(LUNDI)).singleElement()
                .extracting(LigneCotisation::getNomCotisation)
                .isEqualTo(LigneCotisation.normaliserNom("  Épargne  "));
    }

    @Test
    @DisplayName("Un parc vide ne produit rien")
    void parc_vide() {
        when(programmeTravailRepository.findAllWithChauffeurs()).thenReturn(List.of());

        assertThat(useCase.executer(LUNDI)).isEmpty();
    }
}
