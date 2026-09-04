package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

import java.time.LocalDate;

/**
 * Cadrage de la lecture : la période observée, sa base comptable et son état
 * d'avancement. {@code moisEnCours} prévient le lecteur qu'il compare un mois
 * tronqué à un mois complet — sans quoi toute variation serait un faux signal.
 */
public record PeriodeDto(
        int annee,
        int mois,
        /** « Septembre 2026 », pour l'en-tête. */
        String label,
        /** CAISSE ou ENGAGEMENT — celle dans laquelle tout le bloc finance est lu. */
        String base,
        /** Nombre de jours écoulés, servant de dénominateur aux moyennes journalières. */
        int joursEcoules,
        /** Nombre de jours du mois. */
        int joursPeriode,
        boolean moisEnCours,
        /** Vrai si la période est close : les chiffres ne bougeront plus. */
        boolean cloture,
        LocalDate arreteAu
) {}
