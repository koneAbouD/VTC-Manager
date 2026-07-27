package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.Optional;

/**
 * Dotation aux provisions sur créances d'un mois.
 *
 * <p>Ce qui pèse sur le résultat n'est pas le stock de provision mais sa
 * <em>variation</em> : si la provision passe de 152 000 à 180 000, le mois
 * supporte 28 000, pas 180 000. Quand les créances rentrent et que le stock
 * baisse, la variation est négative — c'est une reprise, elle améliore le
 * résultat.
 *
 * <p>Le stock du mois précédent est lu dans la photo de clôture. Sans photo
 * antérieure — premier mois exploité — la dotation vaut le stock entier : c'est
 * la constitution initiale de la provision.
 */
@RequiredArgsConstructor
public class DotationProvisionService {

    private final EtatsClotureRepository etatsClotureRepository;

    /**
     * @param periode      mois calculé
     * @param stockFinMois provision constatée pour ce mois
     */
    public BigDecimal calculer(YearMonth periode, BigDecimal stockFinMois) {
        BigDecimal stock = stockFinMois != null ? stockFinMois : BigDecimal.ZERO;
        return stock.subtract(stockMoisPrecedent(periode));
    }

    private BigDecimal stockMoisPrecedent(YearMonth periode) {
        YearMonth precedent = periode.minusMonths(1);
        Optional<EtatsCloture> archive = etatsClotureRepository
                .findByPeriode(precedent.getYear(), precedent.getMonthValue());
        return archive.map(EtatsCloture::getProvisionCreances)
                .filter(p -> p != null)
                .orElse(BigDecimal.ZERO);
    }
}
