package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Arrays;
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
 * Une indisponibilité devient inerte quand le planning change sous elle : son
 * titulaire ne conduit plus rien, ou ne travaille plus aucun des jours couverts.
 * La laisser active ferait apparaître un congé fantôme sur les écrans de parc.
 * Une indisponibilité en cours est clôturée (les jours déjà passés restent
 * vrais), une indisponibilité à venir est annulée.
 */
class IndisponibiliteNettoyageServiceTest {

    private static final Long TITULAIRE = 1L;
    private static final LocalDate AUJOURDHUI = LocalDate.now();

    private IndisponibiliteRepository indisponibiliteRepository;
    private ProgrammeTravailRepository programmeTravailRepository;
    private IndisponibiliteNettoyageService service;

    @BeforeEach
    void setUp() {
        indisponibiliteRepository = mock(IndisponibiliteRepository.class);
        programmeTravailRepository = mock(ProgrammeTravailRepository.class);
        when(indisponibiliteRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        service = new IndisponibiliteNettoyageService(
                indisponibiliteRepository, programmeTravailRepository);
    }

    private Indisponibilite indispo(IndisponibiliteStatut statut, LocalDate debut, LocalDate fin) {
        return Indisponibilite.builder()
                .id(10L)
                .chauffeur(Chauffeur.builder().id(TITULAIRE).build())
                .dateDebut(debut).dateFin(fin).statut(statut)
                .build();
    }

    /** Programme d'un véhicule conduit par le titulaire, sur les jours donnés. */
    private ProgrammeTravail programme(Set<JourSemaine> joursTravail) {
        return ProgrammeTravail.builder()
                .id(1L).vehiculeId(5L).nombreChauffeursAutorises(1)
                .joursTravailSemaine(joursTravail)
                .chauffeurs(List.of(ProgrammeChauffeur.builder()
                        .chauffeur(Chauffeur.builder().id(TITULAIRE).build())
                        .ordreAlternance(1).build()))
                .build();
    }

    // ── Chauffeur orphelin ──────────────────────────────────────────────────

    @Test
    @DisplayName("Un chauffeur retiré de tout programme voit son congé en cours clôturé")
    void orphelin_congé_en_cours_cloture() {
        Indisponibilite enCours = indispo(
                IndisponibiliteStatut.EN_COURS, AUJOURDHUI.minusDays(2), AUJOURDHUI.plusDays(5));
        when(programmeTravailRepository.findByChauffeurId(TITULAIRE)).thenReturn(Optional.empty());
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE)).thenReturn(List.of(enCours));

        service.nettoyerSiOrphelin(TITULAIRE);

        assertThat(enCours.getStatut()).isEqualTo(IndisponibiliteStatut.TERMINEE);
        // La fin est ramenée à aujourd'hui : les jours passés restent consommés.
        assertThat(enCours.getDateFin()).isEqualTo(AUJOURDHUI);
        assertThat(enCours.getCommentaire()).contains("Clôturée automatiquement")
                .contains("chauffeur retiré de tout programme");
        verify(indisponibiliteRepository).save(enCours);
    }

    @Test
    @DisplayName("Un chauffeur orphelin voit son congé à venir annulé")
    void orphelin_congé_planifie_annule() {
        Indisponibilite planifiee = indispo(
                IndisponibiliteStatut.PLANIFIEE, AUJOURDHUI.plusDays(10), AUJOURDHUI.plusDays(12));
        when(programmeTravailRepository.findByChauffeurId(TITULAIRE)).thenReturn(Optional.empty());
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE)).thenReturn(List.of(planifiee));

        service.nettoyerSiOrphelin(TITULAIRE);

        assertThat(planifiee.getStatut()).isEqualTo(IndisponibiliteStatut.ANNULEE);
        assertThat(planifiee.getCommentaire()).contains("Annulée automatiquement");
    }

    @Test
    @DisplayName("Un chauffeur encore rattaché à un programme garde ses indisponibilités")
    void chauffeur_encore_rattache() {
        when(programmeTravailRepository.findByChauffeurId(TITULAIRE))
                .thenReturn(Optional.of(programme(EnumSet.allOf(JourSemaine.class))));

        service.nettoyerSiOrphelin(TITULAIRE);

        verify(indisponibiliteRepository, never()).findByChauffeurId(anyLong());
        verify(indisponibiliteRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un chauffeur non renseigné est ignoré")
    void chauffeur_nul() {
        service.nettoyerSiOrphelin(null);

        verify(programmeTravailRepository, never()).findByChauffeurId(anyLong());
    }

    @Test
    @DisplayName("Une indisponibilité déjà terminée n'est pas retouchée")
    void deja_terminee_intacte() {
        Indisponibilite terminee = indispo(
                IndisponibiliteStatut.TERMINEE, AUJOURDHUI.minusDays(20), AUJOURDHUI.minusDays(10));
        when(programmeTravailRepository.findByChauffeurId(TITULAIRE)).thenReturn(Optional.empty());
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE)).thenReturn(List.of(terminee));

        service.nettoyerSiOrphelin(TITULAIRE);

        assertThat(terminee.getDateFin()).isEqualTo(AUJOURDHUI.minusDays(10));
        verify(indisponibiliteRepository, never()).save(any());
    }

    // ── Indisponibilités rendues inertes par le planning ────────────────────

    @Test
    @DisplayName("Un congé dont plus aucun jour n'est travaillé est nettoyé")
    void conge_sans_jour_travaille() {
        // Congé sur un seul jour, un lundi ; le véhicule ne roule plus que le samedi.
        LocalDate lundiProchain = prochainJour(java.time.DayOfWeek.MONDAY);
        Indisponibilite planifiee = indispo(
                IndisponibiliteStatut.PLANIFIEE, lundiProchain, lundiProchain);
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE)).thenReturn(List.of(planifiee));

        service.nettoyerInertes(programme(EnumSet.of(JourSemaine.SAMEDI)));

        assertThat(planifiee.getStatut()).isEqualTo(IndisponibiliteStatut.ANNULEE);
        assertThat(planifiee.getCommentaire())
                .contains("le titulaire ne travaille plus aucun jour de la période");
    }

    @Test
    @DisplayName("Un congé couvrant au moins un jour travaillé est conservé")
    void conge_avec_jour_travaille() {
        LocalDate lundiProchain = prochainJour(java.time.DayOfWeek.MONDAY);
        Indisponibilite planifiee = indispo(
                IndisponibiliteStatut.PLANIFIEE, lundiProchain, lundiProchain);
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE)).thenReturn(List.of(planifiee));

        service.nettoyerInertes(programme(EnumSet.of(JourSemaine.LUNDI)));

        assertThat(planifiee.getStatut()).isEqualTo(IndisponibiliteStatut.PLANIFIEE);
        verify(indisponibiliteRepository, never()).save(any());
    }

    @Test
    @DisplayName("Seule la partie à venir du congé est jugée : le passé est déjà consommé")
    void seule_la_partie_a_venir_compte() {
        // Le congé a commencé il y a 10 jours et se termine demain. Le planning
        // ne couvre que le jour d'après-demain : plus aucun jour restant n'est
        // travaillé, l'indisponibilité en cours doit être clôturée.
        JourSemaine jourNonCouvert = JourSemaine.from(AUJOURDHUI.plusDays(3).getDayOfWeek());
        Indisponibilite enCours = indispo(
                IndisponibiliteStatut.EN_COURS, AUJOURDHUI.minusDays(10), AUJOURDHUI.plusDays(1));
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE)).thenReturn(List.of(enCours));

        service.nettoyerInertes(programme(EnumSet.of(jourNonCouvert)));

        assertThat(enCours.getStatut()).isEqualTo(IndisponibiliteStatut.TERMINEE);
    }

    @Test
    @DisplayName("Un programme sans chauffeur ou nul ne déclenche rien")
    void programme_vide() {
        service.nettoyerInertes(null);
        service.nettoyerInertes(ProgrammeTravail.builder().chauffeurs(null).build());

        verify(indisponibiliteRepository, never()).findByChauffeurId(anyLong());
    }

    @Test
    @DisplayName("Les indisponibilités terminées ou annulées ne sont pas réexaminées")
    void statuts_finaux_ignores() {
        Indisponibilite terminee = indispo(
                IndisponibiliteStatut.TERMINEE, AUJOURDHUI.minusDays(5), AUJOURDHUI.minusDays(1));
        Indisponibilite annulee = indispo(
                IndisponibiliteStatut.ANNULEE, AUJOURDHUI.plusDays(5), AUJOURDHUI.plusDays(6));
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE))
                .thenReturn(List.of(terminee, annulee));

        service.nettoyerInertes(programme(EnumSet.of(JourSemaine.SAMEDI)));

        verify(indisponibiliteRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une indisponibilité sans date de début est laissée intacte")
    void sans_date_debut() {
        Indisponibilite sansDebut = indispo(IndisponibiliteStatut.PLANIFIEE, null, null);
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE)).thenReturn(List.of(sansDebut));

        service.nettoyerInertes(programme(EnumSet.of(JourSemaine.SAMEDI)));

        assertThat(sansDebut.getStatut()).isEqualTo(IndisponibiliteStatut.PLANIFIEE);
        verify(indisponibiliteRepository, never()).save(any());
    }

    @Test
    @DisplayName("La trace de nettoyage s'ajoute au commentaire existant sans l'écraser")
    void trace_ajoutee_au_commentaire() {
        Indisponibilite planifiee = indispo(
                IndisponibiliteStatut.PLANIFIEE, AUJOURDHUI.plusDays(10), AUJOURDHUI.plusDays(12));
        planifiee.setCommentaire("Congé annuel");
        when(programmeTravailRepository.findByChauffeurId(TITULAIRE)).thenReturn(Optional.empty());
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE)).thenReturn(List.of(planifiee));

        service.nettoyerSiOrphelin(TITULAIRE);

        assertThat(planifiee.getCommentaire()).startsWith("Congé annuel\n")
                .contains("Annulée automatiquement");
    }

    /** Prochaine occurrence (strictement future) du jour de semaine donné. */
    private LocalDate prochainJour(java.time.DayOfWeek jour) {
        LocalDate date = AUJOURDHUI.plusDays(1);
        while (date.getDayOfWeek() != jour) {
            date = date.plusDays(1);
        }
        return date;
    }

    /** Garde-fou : le service ne doit pas dépendre de l'ordre des jours de la semaine. */
    @Test
    @DisplayName("Un programme couvrant toute la semaine conserve toutes les indisponibilités")
    void programme_toute_la_semaine() {
        Indisponibilite planifiee = indispo(
                IndisponibiliteStatut.PLANIFIEE, AUJOURDHUI.plusDays(1), AUJOURDHUI.plusDays(7));
        when(indisponibiliteRepository.findByChauffeurId(TITULAIRE)).thenReturn(List.of(planifiee));

        service.nettoyerInertes(programme(new java.util.HashSet<>(Arrays.asList(JourSemaine.values()))));

        verify(indisponibiliteRepository, never()).save(any());
    }
}
