package com.tmk.vtcmanager.application.domain.coherence;

import java.time.LocalDate;
import java.util.List;

/**
 * Un chauffeur qui porte, le même jour, des créances sur plusieurs véhicules.
 *
 * <p>Ce n'est pas une erreur de saisie mais une <b>anomalie de programme</b> :
 * la génération quotidienne parcourt les véhicules un par un, et rien ne
 * l'empêche de servir deux fois le même conducteur — le cas se produit
 * naturellement quand un titulaire remplace un collègue absent sans être retiré
 * de son propre programme.
 *
 * <p>On ne bloque pas la génération pour autant : une recette non créée est de
 * l'argent que personne ne réclame, ce qui coûte bien plus cher qu'une recette
 * en trop. On signale, et l'exploitation tranche.
 *
 * @param date             le jour où le conflit se produit — deux journées
 *                         distinctes ne sont pas le même problème
 * @param immatriculations les véhicules concernés, dans l'ordre de lecture
 */
public record ConflitChauffeurJour(LocalDate date, Long chauffeurId, String chauffeurNom,
                                   List<String> immatriculations) {}
