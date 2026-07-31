package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat.BaseComptable;
import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import com.tmk.vtcmanager.application.services.DotationProvisionService;
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
    private final GetProvisionCreancesUseCase getProvisionCreancesUseCase;
    private final DotationProvisionService dotationProvisionService;
    private final FacturePartenaireRepository facturePartenaireRepository;

    /**
     * Cascade des soldes intermédiaires. Base CAISSE : tout est agrégé sur
     * les opérations encaissées/payées de la période. Base ENGAGEMENT : les
     * produits sont remplacés par les montants dus de la période (date
     * métier), et les charges par celles qui y ont été engagées — factures
     * fournisseurs reçues, plus les dépenses réglées sans facture. Le pont
     * créances relie les deux lectures : produits engagement − produits caisse.
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
        BigDecimal produitsEngagement = reportingRepository.produitsEngagement(debut, fin);
        BigDecimal produits = base == BaseComptable.ENGAGEMENT ? produitsEngagement : produitsCaisse;

        // Base CAISSE : ce qui est sorti, règlements de factures compris.
        // Base ENGAGEMENT : ce qui est dû — les factures reçues sur la période,
        // plus les dépenses payées sans facture. Le lien règlement → facture
        // écarte les secondes pour ne pas compter la charge deux fois.
        BigDecimal chargesVariables;
        BigDecimal chargesFixes;
        if (base == BaseComptable.ENGAGEMENT) {
            Map<String, BigDecimal> horsFacture =
                    reportingRepository.totauxCaisseHorsFactureParNature(debut, fin);
            Map<String, BigDecimal> facturees =
                    facturePartenaireRepository.chargesEngageesParNature(debut, fin);
            chargesVariables = horsFacture.getOrDefault("CHARGE_VARIABLE", BigDecimal.ZERO)
                    .add(facturees.getOrDefault("CHARGE_VARIABLE", BigDecimal.ZERO));
            chargesFixes = horsFacture.getOrDefault("CHARGE_FIXE", BigDecimal.ZERO)
                    .add(facturees.getOrDefault("CHARGE_FIXE", BigDecimal.ZERO));
        } else {
            chargesVariables = caisse.getOrDefault("CHARGE_VARIABLE", BigDecimal.ZERO);
            chargesFixes = caisse.getOrDefault("CHARGE_FIXE", BigDecimal.ZERO);
        }

        BigDecimal marge = produits.subtract(chargesVariables);
        BigDecimal ebe = marge.subtract(chargesFixes);
        BigDecimal amortissements = reportingRepository.dotationAmortissements(debut, fin);

        // Perte attendue sur les impayés : la variation du stock de provision,
        // pas le stock lui-même. Le stock n'étant connu qu'à l'instant présent,
        // la dotation n'a de sens que pour le mois en cours ou le dernier mois
        // non clos ; les mois antérieurs la lisent dans leur photo de clôture.
        BigDecimal dotationProvisions = dotationProvisionService.calculer(
                periode, getProvisionCreancesUseCase.executer().getProvisionTotale());

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
                .dotationProvisions(dotationProvisions)
                .resultatGestion(ebe.subtract(amortissements).subtract(dotationProvisions))
                .pontCreances(produitsEngagement.subtract(produitsCaisse))
                .build();
    }

    /** Relit la cascade telle qu'elle a été figée, sans rien recalculer. */
    private CompteResultat depuisArchive(EtatsCloture e, BaseComptable base) {
        BigDecimal produits = base == BaseComptable.ENGAGEMENT
                ? e.getProduitsEngagement() : e.getProduitsCaisse();
        // Les photos antérieures à cette fonctionnalité n'ont pas de dotation.
        BigDecimal dotation = e.getDotationProvisions() != null
                ? e.getDotationProvisions() : BigDecimal.ZERO;
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
                .dotationProvisions(dotation)
                .resultatGestion(ebe.subtract(e.getAmortissements()).subtract(dotation))
                .pontCreances(e.getPontCreances())
                .build();
    }
}
