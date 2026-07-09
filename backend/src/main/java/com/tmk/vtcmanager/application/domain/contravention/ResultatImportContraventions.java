package com.tmk.vtcmanager.application.domain.contravention;

/**
 * Bilan d'une confirmation d'import de contraventions.
 *
 * @param contraventionsCreees   nombre de contraventions persistées
 * @param contraventionsRattachees nombre de contraventions rattachées à un chauffeur
 * @param doublonsIgnores        nombre de numéros déjà présents, non réimportés
 */
public record ResultatImportContraventions(
        int contraventionsCreees,
        int contraventionsRattachees,
        int doublonsIgnores
) {}
