package com.tmk.vtcmanager.application.domain.reaffectation;

/**
 * Un chauffeur soumis au jugement du serveur pour reprendre une créance.
 *
 * <p>C'est le serveur qui tranche, jamais l'écran : la règle « un chauffeur, un
 * véhicule, un jour » vit d'un seul côté, et un client qui la rejouerait
 * finirait par diverger d'elle. L'écran ne fait qu'afficher ce verdict — et
 * l'affiche même quand il est négatif : masquer un chauffeur pris ailleurs
 * laisserait le chercher, le laisser choisissable serait un piège.
 *
 * @param auProgramme il figure au programme du véhicule ce jour-là, remplacements
 *                    compris — sert à ranger la liste, pas à filtrer
 * @param actuel      c'est le chauffeur actuellement porté par la ligne
 * @param motif       ce qui l'empêche d'être choisi ; ou, quand il l'est, ce
 *                    qu'il porte déjà ce jour-là
 */
public record CandidatReaffectation(Long chauffeurId, String nom, boolean auProgramme,
                                    boolean actuel, boolean eligible, String motif) {}
