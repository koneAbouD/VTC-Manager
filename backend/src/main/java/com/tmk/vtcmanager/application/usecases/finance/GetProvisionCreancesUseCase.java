package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.ProvisionCreances;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.ParametreGeneralRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

/**
 * Dépréciation des créances chauffeurs à l'instant présent.
 *
 * <p>Les taux sont lus dans les paramètres généraux, tranche par tranche : la
 * politique de provisionnement est une décision de gestion, elle n'a pas à être
 * figée dans le code.
 */
@RequiredArgsConstructor
public class GetProvisionCreancesUseCase {

    static final String CLE_TAUX_0_7 = "PROVISION_CREANCES_TAUX_0_7";
    static final String CLE_TAUX_8_30 = "PROVISION_CREANCES_TAUX_8_30";
    static final String CLE_TAUX_PLUS_30 = "PROVISION_CREANCES_TAUX_PLUS_30";

    private static final BigDecimal CENT = BigDecimal.valueOf(100);

    private final CreanceRepository creanceRepository;
    private final ParametreGeneralRepository parametreGeneralRepository;

    @Transactional(readOnly = true)
    public ProvisionCreances executer() {
        List<CreanceChauffeur> balance = creanceRepository.getBalanceAgee();

        BigDecimal base0a7 = somme(balance, CreanceChauffeur::getDu0a7Jours);
        BigDecimal base8a30 = somme(balance, CreanceChauffeur::getDu8a30Jours);
        BigDecimal basePlus30 = somme(balance, CreanceChauffeur::getDuPlus30Jours);

        BigDecimal taux0a7 = taux(CLE_TAUX_0_7, BigDecimal.ZERO);
        BigDecimal taux8a30 = taux(CLE_TAUX_8_30, BigDecimal.valueOf(25));
        BigDecimal tauxPlus30 = taux(CLE_TAUX_PLUS_30, BigDecimal.valueOf(50));

        BigDecimal provision0a7 = appliquer(base0a7, taux0a7);
        BigDecimal provision8a30 = appliquer(base8a30, taux8a30);
        BigDecimal provisionPlus30 = appliquer(basePlus30, tauxPlus30);
        BigDecimal provisionTotale = provision0a7.add(provision8a30).add(provisionPlus30);
        BigDecimal brutes = base0a7.add(base8a30).add(basePlus30);

        return ProvisionCreances.builder()
                .creancesBrutes(brutes)
                .base0a7Jours(base0a7)
                .base8a30Jours(base8a30)
                .basePlus30Jours(basePlus30)
                .taux0a7Jours(taux0a7)
                .taux8a30Jours(taux8a30)
                .tauxPlus30Jours(tauxPlus30)
                .provision0a7Jours(provision0a7)
                .provision8a30Jours(provision8a30)
                .provisionPlus30Jours(provisionPlus30)
                .provisionTotale(provisionTotale)
                .creancesNettes(brutes.subtract(provisionTotale))
                .build();
    }

    private BigDecimal somme(List<CreanceChauffeur> balance,
                             java.util.function.Function<CreanceChauffeur, BigDecimal> champ) {
        return balance.stream()
                .map(champ)
                .filter(java.util.Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /** Provision arrondie au franc : le XOF n'a pas de subdivision. */
    private BigDecimal appliquer(BigDecimal base, BigDecimal tauxPourcent) {
        return base.multiply(tauxPourcent)
                .divide(CENT, 0, RoundingMode.HALF_UP);
    }

    private BigDecimal taux(String cle, BigDecimal defaut) {
        return parametreGeneralRepository.findByCle(cle)
                .map(p -> {
                    try {
                        return new BigDecimal(p.getValeur().trim());
                    } catch (NumberFormatException e) {
                        return defaut;
                    }
                })
                .orElse(defaut);
    }
}
