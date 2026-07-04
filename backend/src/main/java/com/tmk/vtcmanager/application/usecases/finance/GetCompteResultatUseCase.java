package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat.BaseComptable;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.Map;

@RequiredArgsConstructor
public class GetCompteResultatUseCase {

    private final FinanceReportingRepository reportingRepository;

    /**
     * Cascade des soldes intermédiaires. Base CAISSE : tout est agrégé sur
     * les opérations encaissées/payées de la période. Base ENGAGEMENT : les
     * produits sont remplacés par les montants dus de la période (date
     * métier) ; les charges restent celles de la caisse (payées = engagées
     * dans ce modèle sans dette fournisseur). Le pont créances relie les
     * deux lectures : produits engagement − produits caisse.
     */
    @Transactional(readOnly = true)
    public CompteResultat executer(int annee, int mois, BaseComptable base) {
        YearMonth periode = YearMonth.of(annee, mois);
        LocalDate debut = periode.atDay(1);
        LocalDate fin = periode.atEndOfMonth();

        Map<String, BigDecimal> caisse = reportingRepository.totauxCaisseParNature(debut, fin);
        BigDecimal produitsCaisse = caisse.getOrDefault("PRODUIT_EXPLOITATION", BigDecimal.ZERO);
        BigDecimal chargesVariables = caisse.getOrDefault("CHARGE_VARIABLE", BigDecimal.ZERO);
        BigDecimal chargesFixes = caisse.getOrDefault("CHARGE_FIXE", BigDecimal.ZERO);

        BigDecimal produitsEngagement = reportingRepository.produitsEngagement(debut, fin);
        BigDecimal produits = base == BaseComptable.ENGAGEMENT ? produitsEngagement : produitsCaisse;

        BigDecimal marge = produits.subtract(chargesVariables);
        BigDecimal ebe = marge.subtract(chargesFixes);
        BigDecimal amortissements = reportingRepository.dotationAmortissements(debut, fin);

        return CompteResultat.builder()
                .annee(annee)
                .mois(mois)
                .base(base)
                .produitsExploitation(produits)
                .chargesVariables(chargesVariables)
                .margeSurCoutsVariables(marge)
                .chargesFixes(chargesFixes)
                .excedentBrutExploitation(ebe)
                .amortissements(amortissements)
                .resultatGestion(ebe.subtract(amortissements))
                .pontCreances(produitsEngagement.subtract(produitsCaisse))
                .build();
    }
}
