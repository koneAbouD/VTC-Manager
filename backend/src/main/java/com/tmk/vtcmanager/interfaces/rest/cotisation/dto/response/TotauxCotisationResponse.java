package com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response;

import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.TotalCotisationParStatut;

import java.math.BigDecimal;
import java.util.List;

/**
 * Cumuls d'une sélection de lignes de cotisation : le total, puis le détail par
 * statut. Sert les compteurs de l'écran, que la liste paginée ne peut pas
 * calculer — elle n'a chargé que ses premières pages.
 *
 * @param parStatut tous les statuts, y compris ceux sans ligne (montants à zéro).
 */
public record TotauxCotisationResponse(
        long nombre,
        BigDecimal montantDu,
        BigDecimal montantEncaisse,
        List<TotalStatutResponse> parStatut) {

    public record TotalStatutResponse(
            StatutLigneCotisation statut,
            long nombre,
            BigDecimal montantDu,
            BigDecimal montantEncaisse) {
    }

    public static TotauxCotisationResponse from(List<TotalCotisationParStatut> totaux) {
        return new TotauxCotisationResponse(
                totaux.stream().mapToLong(TotalCotisationParStatut::nombre).sum(),
                somme(totaux, TotalCotisationParStatut::montantDu),
                somme(totaux, TotalCotisationParStatut::montantEncaisse),
                totaux.stream()
                        .map(t -> new TotalStatutResponse(
                                t.statut(), t.nombre(), montant(t.montantDu()), montant(t.montantEncaisse())))
                        .toList());
    }

    private static BigDecimal somme(List<TotalCotisationParStatut> totaux,
                                    java.util.function.Function<TotalCotisationParStatut, BigDecimal> champ) {
        return totaux.stream()
                .map(champ)
                .map(TotauxCotisationResponse::montant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static BigDecimal montant(BigDecimal valeur) {
        return valeur != null ? valeur : BigDecimal.ZERO;
    }
}
