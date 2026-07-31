package com.tmk.vtcmanager.application.domain.partenaire;

import java.math.BigDecimal;

/**
 * Ce que couvre une dette, ligne à ligne.
 *
 * <p>Une dette née d'une intervention ne dit rien par son seul montant : savoir
 * qu'on doit 45 000 F au garage n'aide pas, savoir que c'est pour les plaquettes
 * et la main d'œuvre, si. Seules les lignes revenant au partenaire de la dette
 * sont reprises ici.
 *
 * @param libelle élément de maintenance, tel qu'il a été saisi
 * @param montant part de la dette portée par cette ligne
 */
public record LigneDette(String libelle, BigDecimal montant) {}
