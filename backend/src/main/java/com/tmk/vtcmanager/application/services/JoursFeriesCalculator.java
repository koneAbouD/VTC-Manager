package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.jourFerie.JourFerie;
import com.tmk.vtcmanager.application.domain.jourFerie.SourceJourFerie;
import com.tmk.vtcmanager.application.domain.jourFerie.TypeJourFerie;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Calcule les jours fériés déterministes de Côte d'Ivoire pour une année :
 * fériés civils fixes et fêtes chrétiennes mobiles (dérivées de Pâques).
 *
 * <p>Les fêtes musulmanes (Aïd el-Fitr, Tabaski, Maouloud, Lendemain de la Nuit
 * du Destin) suivent le calendrier lunaire et sont fixées par décret ~48h avant :
 * elles ne sont pas calculées ici et doivent être saisies/confirmées à la main.</p>
 */
public class JoursFeriesCalculator {

    /** Fériés déterministes de l'année, source AUTO. */
    public List<JourFerie> genererAnnee(int annee) {
        List<JourFerie> feries = new ArrayList<>();

        // Fériés civils fixes
        feries.add(auto(LocalDate.of(annee, 1, 1), "Jour de l'An", TypeJourFerie.FIXE));
        feries.add(auto(LocalDate.of(annee, 5, 1), "Fête du Travail", TypeJourFerie.FIXE));
        feries.add(auto(LocalDate.of(annee, 8, 7), "Fête Nationale", TypeJourFerie.FIXE));
        feries.add(auto(LocalDate.of(annee, 8, 15), "Assomption", TypeJourFerie.FIXE));
        feries.add(auto(LocalDate.of(annee, 11, 1), "Toussaint", TypeJourFerie.FIXE));
        feries.add(auto(LocalDate.of(annee, 11, 15), "Journée Nationale de la Paix", TypeJourFerie.FIXE));
        feries.add(auto(LocalDate.of(annee, 12, 25), "Noël", TypeJourFerie.FIXE));

        // Fêtes chrétiennes mobiles (dérivées de Pâques)
        LocalDate paques = paques(annee);
        feries.add(auto(paques.plusDays(1), "Lundi de Pâques", TypeJourFerie.CHRETIEN));
        feries.add(auto(paques.plusDays(39), "Ascension", TypeJourFerie.CHRETIEN));
        feries.add(auto(paques.plusDays(50), "Lundi de Pentecôte", TypeJourFerie.CHRETIEN));

        return feries;
    }

    private JourFerie auto(LocalDate date, String libelle, TypeJourFerie type) {
        return JourFerie.builder()
                .date(date)
                .libelle(libelle)
                .type(type)
                .annee(date.getYear())
                .source(SourceJourFerie.AUTO)
                .build();
    }

    /** Dimanche de Pâques (grégorien) — algorithme « Anonymous Gregorian » (Meeus/Butcher). */
    private LocalDate paques(int annee) {
        int a = annee % 19;
        int b = annee / 100;
        int c = annee % 100;
        int d = b / 4;
        int e = b % 4;
        int f = (b + 8) / 25;
        int g = (b - f + 1) / 3;
        int h = (19 * a + b - d - g + 15) % 30;
        int i = c / 4;
        int k = c % 4;
        int l = (32 + 2 * e + 2 * i - h - k) % 7;
        int m = (a + 11 * h + 22 * l) / 451;
        int mois = (h + l - 7 * m + 114) / 31;
        int jour = ((h + l - 7 * m + 114) % 31) + 1;
        return LocalDate.of(annee, mois, jour);
    }
}
