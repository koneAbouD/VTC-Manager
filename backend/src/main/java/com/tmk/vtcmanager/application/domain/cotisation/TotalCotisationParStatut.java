package com.tmk.vtcmanager.application.domain.cotisation;

import java.math.BigDecimal;

/**
 * Cumul des lignes de cotisation d'un statut, sur les filtres demandés.
 *
 * <p>Répond à une question que la liste paginée ne peut pas trancher : le total
 * d'un mois porte sur toutes ses lignes, pas sur les premières pages chargées.
 * Additionner ce que le scroll a ramené donnait un chiffre qui grandissait à
 * mesure qu'on descendait.</p>
 *
 * @param nombre          lignes comptées.
 * @param montantDu       ce que ces lignes réclament.
 * @param montantEncaisse ce qui en a été versé.
 */
public record TotalCotisationParStatut(
        StatutLigneCotisation statut,
        long nombre,
        BigDecimal montantDu,
        BigDecimal montantEncaisse) {
}
