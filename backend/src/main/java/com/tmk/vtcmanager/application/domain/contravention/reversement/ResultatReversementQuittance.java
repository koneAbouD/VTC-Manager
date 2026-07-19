package com.tmk.vtcmanager.application.domain.contravention.reversement;

/**
 * Bilan d'une confirmation de reversement par quittance.
 *
 * @param reversees      nombre de contraventions effectivement reversées (REVERSE + dépense)
 * @param dejaReversees  nombre ignorées car déjà au statut REVERSE (idempotence)
 * @param ignorees       nombre ignorées (id introuvable ou non sélectionnable)
 */
public record ResultatReversementQuittance(
        int reversees,
        int dejaReversees,
        int ignorees
) {}
