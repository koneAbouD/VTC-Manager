package com.tmk.vtcmanager.application.domain.programmeTravail;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProgrammeTravail {

    private Long id;
    private Long vehiculeId;
    private Integer nombreChauffeursAutorises;
    private TypeProgrammeTravail typeProgramme;
    private LocalTime heureDebutService;
    private LocalTime heureFinService;
    private ModeAlternance modeAlternance;
    private Integer joursAlternance;
    private LocalDate dateDebutAlternance;
    @Builder.Default
    private Set<JourSemaine> joursAlternanceSemaine = new HashSet<>();
    /** Jours de la semaine où le véhicule travaille. Vide = tous les jours. */
    @Builder.Default
    private Set<JourSemaine> joursTravailSemaine = new HashSet<>();
    private boolean jourSalaireActif;
    private JourSemaine jourSalaire;
    @Builder.Default
    private List<ProgrammeChauffeur> chauffeurs = new ArrayList<>();

    /**
     * Réaligne le programme avec la condition de travail du véhicule.
     * La condition demeure la source unique des règles, tandis que le programme
     * ne conserve que l'assignation des chauffeurs et les jours partagés.
     */
    public void synchronizeWithCondition(ConditionTravail condition) {
        if (condition == null) {
            return;
        }
        nombreChauffeursAutorises = condition.getNbChauffeurs();
        if (condition.getTypeProgramme() != null) {
            typeProgramme = TypeProgrammeTravail.valueOf(condition.getTypeProgramme());
        }
        if (condition.getHeureDebutService() != null) {
            heureDebutService = LocalTime.parse(condition.getHeureDebutService());
        }
        if (condition.getHeureFinService() != null) {
            heureFinService = LocalTime.parse(condition.getHeureFinService());
        }
        modeAlternance = condition.getModeAlternance() != null
                ? ModeAlternance.valueOf(condition.getModeAlternance())
                : ModeAlternance.MANUELLE;
        joursAlternance = condition.getJoursAlternance();
        dateDebutAlternance = condition.getDateDebutAlternance();
        if (condition.getJourSalaire() != null) {
            jourSalaire = JourSemaine.valueOf(condition.getJourSalaire());
            jourSalaireActif = true;
        } else {
            jourSalaire = null;
            jourSalaireActif = false;
        }

        // Jours de travail de la semaine
        if (condition.getJoursTravail() != null && !condition.getJoursTravail().isEmpty()) {
            joursTravailSemaine = condition.getJoursTravail().stream()
                    .map(JourSemaine::valueOf)
                    .collect(java.util.stream.Collectors.toSet());
        } else {
            joursTravailSemaine = new HashSet<>();
        }
        // Avec 2 chauffeurs, la validation exige au moins un jour partagé.
        // Tant que la condition de travail ne porte pas cette information,
        // on initialise la semaine complète comme défaut.
        if (nombreChauffeursAutorises != null && nombreChauffeursAutorises > 1
                && (joursAlternanceSemaine == null || joursAlternanceSemaine.isEmpty())) {
            joursAlternanceSemaine = new HashSet<>(java.util.Arrays.asList(JourSemaine.values()));
        }
        // Mode AUTOMATIQUE avec 2 chauffeurs : valeurs par défaut si non fournies
        if (nombreChauffeursAutorises != null && nombreChauffeursAutorises > 1
                && modeAlternance == ModeAlternance.AUTOMATIQUE) {
            if (joursAlternance == null) {
                joursAlternance = 1;
            }
            if (dateDebutAlternance == null) {
                dateDebutAlternance = LocalDate.now();
            }
        }
    }

    public static ProgrammeTravail defaultForVehicule(Long vehiculeId) {
        return ProgrammeTravail.builder()
                .vehiculeId(vehiculeId)
                .nombreChauffeursAutorises(1)
                .typeProgramme(TypeProgrammeTravail.JOURNALIER)
                .heureDebutService(LocalTime.of(8, 0))
                .heureFinService(LocalTime.of(20, 0))
                .modeAlternance(ModeAlternance.MANUELLE)
                .jourSalaireActif(false)
                .jourSalaire(JourSemaine.DIMANCHE)
                .chauffeurs(new ArrayList<>())
                .build();
    }

    public void normalize() {
        if (chauffeurs == null) {
            chauffeurs = new ArrayList<>();
        }

        chauffeurs.removeIf(pc -> pc == null || pc.getChauffeurId() == null);

        normalizeAlternanceOrders();
        normalizeSalaryOrders();

        // Champs AUTOMATIQUE : nuls si pas applicable
        boolean isAutoAvecDeuxChauffeurs = modeAlternance == ModeAlternance.AUTOMATIQUE
                && nombreChauffeursAutorises != null && nombreChauffeursAutorises > 1;
        if (!isAutoAvecDeuxChauffeurs) {
            joursAlternance = null;
            dateDebutAlternance = null;
        }

        // Jours de travail partagés : nuls si 1 seul chauffeur autorisé
        if (nombreChauffeursAutorises == null || nombreChauffeursAutorises <= 1) {
            if (joursAlternanceSemaine != null) joursAlternanceSemaine.clear();
        }
    }

    public void validate() {
        if (vehiculeId == null) {
            throw new IllegalArgumentException("Le véhicule à configurer est obligatoire.");
        }
        if (nombreChauffeursAutorises == null || nombreChauffeursAutorises < 1 || nombreChauffeursAutorises > 2) {
            throw new IllegalArgumentException("Le nombre de chauffeurs autorisés doit être compris entre 1 et 2.");
        }
        if (typeProgramme == null) {
            throw new IllegalArgumentException("Le programme de travail est obligatoire.");
        }
        if (heureDebutService == null || heureFinService == null) {
            throw new IllegalArgumentException("Les heures de début et de fin de service sont obligatoires.");
        }
        if (heureFinService.equals(heureDebutService)) {
            throw new IllegalArgumentException(
                    "L'heure de fin de service doit être différente de l'heure de début.");
        }
        if (modeAlternance == null) {
            throw new IllegalArgumentException("Le mode d'alternance est obligatoire.");
        }
        if (chauffeurs.size() > nombreChauffeursAutorises) {
            throw new IllegalArgumentException("Le nombre de chauffeurs configurés dépasse le maximum autorisé pour ce véhicule.");
        }
        if (nombreChauffeursAutorises == 2 && chauffeurs.size() < 2) {
            throw new IllegalArgumentException("Vous devez affecter exactement 2 chauffeurs lorsque le nombre autorisé est 2.");
        }
        if (jourSalaireActif && jourSalaire == null) {
            throw new IllegalArgumentException("Le jour de salaire doit être renseigné lorsqu'il est activé.");
        }
        // Jours de travail partagés requis dès que 2 chauffeurs autorisés
        if (nombreChauffeursAutorises > 1 && (joursAlternanceSemaine == null || joursAlternanceSemaine.isEmpty())) {
            throw new IllegalArgumentException("Sélectionnez au moins un jour de travail pour les deux chauffeurs.");
        }

        // Champs spécifiques au mode AUTOMATIQUE avec 2 chauffeurs
        if (modeAlternance == ModeAlternance.AUTOMATIQUE && nombreChauffeursAutorises > 1) {
            if (joursAlternance == null || joursAlternance < 1 || joursAlternance > 3) {
                throw new IllegalArgumentException("Le nombre de jours d'alternance doit être compris entre 1 et 3 pour une alternance automatique.");
            }
            if (dateDebutAlternance == null) {
                throw new IllegalArgumentException("La date de début d'alternance est obligatoire pour une alternance automatique.");
            }
        }

        validateDistinctChauffeurs();
        validateOrders(chauffeurs.stream().map(ProgrammeChauffeur::getOrdreAlternance).toList(), "d'alternance");
        if (jourSalaireActif) {
            validateOrders(chauffeurs.stream().map(ProgrammeChauffeur::getOrdreJourSalaire).toList(), "de jour de salaire");
        }
    }

    public void invertChauffeurs() {
        if (chauffeurs == null || chauffeurs.size() < 2) {
            throw new IllegalArgumentException("Il faut au moins 2 chauffeurs configurés pour inverser le programme.");
        }

        normalize();

        int maxAlternance = chauffeurs.stream()
                .map(ProgrammeChauffeur::getOrdreAlternance)
                .filter(order -> order != null && order > 0)
                .max(Integer::compareTo)
                .orElse(chauffeurs.size());

        for (ProgrammeChauffeur pc : chauffeurs) {
            if (pc.getOrdreAlternance() != null) {
                pc.setOrdreAlternance((maxAlternance + 1) - pc.getOrdreAlternance());
            }
        }

        if (jourSalaireActif) {
            int maxSalaire = chauffeurs.stream()
                    .map(ProgrammeChauffeur::getOrdreJourSalaire)
                    .filter(order -> order != null && order > 0)
                    .max(Integer::compareTo)
                    .orElse(chauffeurs.size());

            for (ProgrammeChauffeur pc : chauffeurs) {
                if (pc.getOrdreJourSalaire() != null) {
                    pc.setOrdreJourSalaire((maxSalaire + 1) - pc.getOrdreJourSalaire());
                }
            }
        }
    }

    private void validateDistinctChauffeurs() {
        Set<Long> ids = new HashSet<>();
        for (ProgrammeChauffeur pc : chauffeurs) {
            if (!ids.add(pc.getChauffeurId())) {
                throw new IllegalArgumentException("Un chauffeur ne peut être sélectionné qu'une seule fois dans le programme.");
            }
        }
    }

    private void validateOrders(List<Integer> orders, String label) {
        List<Integer> filtered = orders.stream().filter(order -> order != null).toList();
        Set<Integer> unique = new HashSet<>(filtered);
        if (filtered.size() != unique.size()) {
            throw new IllegalArgumentException("Les ordres " + label + " doivent être uniques.");
        }
        for (Integer order : filtered) {
            if (order < 1) {
                throw new IllegalArgumentException("Les ordres " + label + " doivent être positifs.");
            }
        }
    }

    private void normalizeAlternanceOrders() {
        List<ProgrammeChauffeur> sorted = new ArrayList<>(chauffeurs);
        sorted.sort(Comparator.comparing(
                pc -> pc.getOrdreAlternance() == null ? Integer.MAX_VALUE : pc.getOrdreAlternance()
        ));
        int index = 1;
        for (ProgrammeChauffeur pc : sorted) {
            pc.setOrdreAlternance(index++);
        }
    }

    private void normalizeSalaryOrders() {
        if (!jourSalaireActif) {
            for (ProgrammeChauffeur pc : chauffeurs) {
                pc.setOrdreJourSalaire(null);
            }
            return;
        }

        List<ProgrammeChauffeur> sorted = new ArrayList<>(chauffeurs);
        sorted.sort(Comparator.comparing(
                pc -> pc.getOrdreJourSalaire() == null ? Integer.MAX_VALUE : pc.getOrdreJourSalaire()
        ));
        int index = 1;
        for (ProgrammeChauffeur pc : sorted) {
            pc.setOrdreJourSalaire(index++);
        }
    }
}
