package com.tmk.vtcmanager.application.domain.finance;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Plan d'amortissement d'un véhicule, lu au même endroit que le bilan.
 *
 * <p>La fiche véhicule et l'actif du bilan doivent afficher la même valeur : une
 * seconde formule, tenue à part, finissait par désigner un autre point de départ
 * et un autre rythme.
 *
 * @param dureeMois durée effective : override du véhicule, sinon le paramètre
 *                  global, sinon 60.
 * @param depart    premier jour amorti — l'entrée en flotte fait foi, l'achat et
 *                  la mise en circulation ne sont que des replis. {@code null}
 *                  si aucune des trois dates n'est connue.
 * @param valeurNetteComptable prix d'achat − amortissement couru à la date
 *                  demandée, borné à 0. {@code null} quand le véhicule n'est pas
 *                  amortissable (prix d'achat absent, plan inexploitable) ou que
 *                  son plan n'a pas encore commencé : il n'est alors pas non plus
 *                  porté à l'actif du bilan.
 */
public record AmortissementVehicule(
        Long vehiculeId,
        int dureeMois,
        LocalDate depart,
        BigDecimal valeurNetteComptable
) {}
