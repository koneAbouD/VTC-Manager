package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat.BaseComptable;
import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
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
    private final EtatsClotureRepository etatsClotureRepository;

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
        // Mois clos : on sert la photo prise à la clôture. Un recalcul pourrait
        // donner un autre chiffre qu'à la publication — ce serait le signe que
        // l'état n'était opposable à personne.
        var archive = etatsClotureRepository.findByPeriode(annee, mois);
        if (archive.isPresent()) {
            return depuisArchive(archive.get(), base);
        }

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

    /** Relit la cascade telle qu'elle a été figée, sans rien recalculer. */
    private CompteResultat depuisArchive(EtatsCloture e, BaseComptable base) {
        BigDecimal produits = base == BaseComptable.ENGAGEMENT
                ? e.getProduitsEngagement() : e.getProduitsCaisse();
        BigDecimal marge = produits.subtract(e.getChargesVariables());
        BigDecimal ebe = marge.subtract(e.getChargesFixes());
        return CompteResultat.builder()
                .annee(e.getAnnee())
                .mois(e.getMois())
                .base(base)
                .produitsExploitation(produits)
                .chargesVariables(e.getChargesVariables())
                .margeSurCoutsVariables(marge)
                .chargesFixes(e.getChargesFixes())
                .excedentBrutExploitation(ebe)
                .amortissements(e.getAmortissements())
                .resultatGestion(ebe.subtract(e.getAmortissements()))
                .pontCreances(e.getPontCreances())
                .build();
    }
}
