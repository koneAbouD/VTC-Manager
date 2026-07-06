package com.tmk.vtcmanager.application.domain.conditionTravail;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
public class ConditionTravail {
    Long id;
    String nom;
    int nbChauffeurs;
    String typeProgramme;
    String heureDebutService;
    String heureFinService;
    // Présent seulement si nbChauffeurs == 2
    String modeAlternance;
    // Présent seulement si nbChauffeurs == 2 && modeAlternance == AUTOMATIQUE
    Integer joursAlternance;
    LocalDate dateDebutAlternance;
    // Null si jourSalaire désactivé côté mobile
    String jourSalaire;
    BigDecimal objectifRecette;
    // MONTANT_FIXE | MONTANT_REEL
    String typeRecette;
    // Null si typeRecette == MONTANT_REEL
    BigDecimal montantJourSalaire;
    // Prise en compte des jours fériés (suspend recette/cotisation ces jours-là)
    boolean feriesConsideres;
    // Recette due le jour férié (recette fixe) ; null/0 = aucune recette due
    BigDecimal montantJourFerie;
    // ESPECES | MOBILE_MONEY | LES_DEUX
    String modeEncaissement;
    // JOURNALIER | HEBDOMADAIRE
    String frequenceVersement;
    // Null si frequenceVersement != HEBDOMADAIRE
    String jourVersement;
    String heureVersement;
    // Jours de travail de la semaine — vide = tous les jours (JOURNALIER)
    List<String> joursTravail;
    List<CotisationTemplate> cotisations;
    List<PenaliteTemplate> penalites;
}
