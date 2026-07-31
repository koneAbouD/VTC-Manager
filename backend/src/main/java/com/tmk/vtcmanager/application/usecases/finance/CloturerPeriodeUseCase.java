package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.exception.PeriodeNonCloturableException;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import com.tmk.vtcmanager.application.services.DotationProvisionService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;

@RequiredArgsConstructor
public class CloturerPeriodeUseCase {

    private final CloturePeriodeRepository cloturePeriodeRepository;
    private final ClotureCaisseRepository clotureCaisseRepository;
    private final CompteTresorerieRepository compteTresorerieRepository;
    private final CreanceRepository creanceRepository;
    private final FinanceReportingRepository reportingRepository;
    private final EtatsClotureRepository etatsClotureRepository;
    private final GetCompteResultatUseCase getCompteResultatUseCase;
    private final GetProvisionCreancesUseCase getProvisionCreancesUseCase;
    private final DotationProvisionService dotationProvisionService;
    private final FacturePartenaireRepository facturePartenaireRepository;

    /**
     * Clôture un mois strictement passé (jamais le mois courant : les
     * opérations du jour, datées d'aujourd'hui, doivent rester possibles).
     * Les clôtures doivent être contiguës : on clôture le mois qui suit la
     * dernière période clôturée — pas de trou dans le verrou.
     *
     * <p>Deux garde-fous avant de figer : chaque caisse active doit avoir été
     * comptée dans le mois, et aucun écart de caisse ne doit rester en attente
     * d'imputation. Clôturer sur des écarts non tranchés reviendrait à publier
     * un résultat dont on sait déjà qu'il est incomplet.
     *
     * <p>La clôture archive enfin les états du mois : c'est cette photo qui sera
     * servie ensuite, plutôt qu'un recalcul qui pourrait changer.
     */
    @Transactional
    public CloturePeriode executer(int annee, int mois) {
        YearMonth periode = YearMonth.of(annee, mois);
        if (!periode.isBefore(YearMonth.now())) {
            throw new PeriodeNonCloturableException(
                    "Seul un mois strictement passé peut être clôturé");
        }
        if (cloturePeriodeRepository.existsByAnneeAndMois(annee, mois)) {
            throw new PeriodeNonCloturableException(
                    "La période " + mois + "/" + annee + " est déjà clôturée");
        }
        cloturePeriodeRepository.findDerniere().ifPresent(derniere -> {
            YearMonth attendue = YearMonth.of(derniere.getAnnee(), derniere.getMois()).plusMonths(1);
            if (!periode.equals(attendue)) {
                throw new PeriodeNonCloturableException(
                        "La prochaine période à clôturer est " + attendue.getMonthValue()
                                + "/" + attendue.getYear());
            }
        });

        LocalDate debut = periode.atDay(1);
        LocalDate fin = periode.atEndOfMonth();
        verifierCaisses(debut, fin);

        CloturePeriode cloture = cloturePeriodeRepository.save(CloturePeriode.builder()
                .annee(annee)
                .mois(mois)
                .dateCloture(LocalDateTime.now())
                .build());

        etatsClotureRepository.save(construireEtats(cloture, annee, mois, fin));
        return cloture;
    }

    /** Aucune caisse laissée sans comptage, aucun écart laissé sans décision. */
    private void verifierCaisses(LocalDate debut, LocalDate fin) {
        for (CompteTresorerie compte : compteTresorerieRepository.findByActifTrue()) {
            List<ClotureCaisse> clotures =
                    clotureCaisseRepository.findByCompteIdOrderByDateDesc(compte.getId());

            boolean compteeDansLaPeriode = clotures.stream().anyMatch(c ->
                    !c.getDateCloture().isBefore(debut) && !c.getDateCloture().isAfter(fin));
            if (!compteeDansLaPeriode) {
                throw new PeriodeNonCloturableException("Le compte « " + compte.getLibelle()
                        + " » n'a pas été clôturé sur la période : comptez-le avant de clôturer le mois.");
            }

            clotures.stream()
                    .filter(c -> !c.getDateCloture().isBefore(debut) && !c.getDateCloture().isAfter(fin))
                    .filter(ClotureCaisse::attendImputation)
                    .findFirst()
                    .ifPresent(c -> {
                        throw new PeriodeNonCloturableException("L'écart de caisse du "
                                + c.getDateCloture() + " sur « " + compte.getLibelle()
                                + " » attend encore son imputation.");
                    });
        }
    }

    private EtatsCloture construireEtats(CloturePeriode cloture, int annee, int mois, LocalDate fin) {
        CompteResultat caisse = getCompteResultatUseCase.executer(
                annee, mois, CompteResultat.BaseComptable.CAISSE);
        CompteResultat engagement = getCompteResultatUseCase.executer(
                annee, mois, CompteResultat.BaseComptable.ENGAGEMENT);

        // Trésorerie : arrêtée au dernier jour du mois, compte par compte.
        List<EtatsCloture.SoldeCompteCloture> soldes = new ArrayList<>();
        BigDecimal tresorerie = BigDecimal.ZERO;
        for (CompteTresorerie compte : compteTresorerieRepository.findAll()) {
            BigDecimal solde = compteTresorerieRepository
                    .findAvecSoldeALaDate(compte.getId(), fin)
                    .map(CompteAvecSolde::getSolde)
                    .orElse(BigDecimal.ZERO);
            soldes.add(EtatsCloture.SoldeCompteCloture.builder()
                    .compteId(compte.getId())
                    .libelleCompte(compte.getLibelle())
                    .solde(solde)
                    .build());
            tresorerie = tresorerie.add(solde);
        }

        // Créances et dette État : pris à l'instant de la clôture — la balance
        // âgée ne se rejoue pas à une date passée.
        BigDecimal creances = creanceRepository.getBalanceAgee().stream()
                .map(CreanceChauffeur::getTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        // Même lecture qu'à l'écran : c'est le net de dépréciation qui entre à
        // l'actif, sinon la photo et le bilan courant se contrediraient.
        BigDecimal provision = getProvisionCreancesUseCase.executer().getProvisionTotale();
        BigDecimal creancesNettes = creances.subtract(provision);
        // Ce que le mois supporte : la variation par rapport à la photo du mois
        // précédent, pas le stock.
        BigDecimal dotation = dotationProvisionService.calculer(
                YearMonth.of(annee, mois), provision);

        BigDecimal immobilisations = reportingRepository.immobilisationsNettes(fin);
        BigDecimal detteEtat = creanceRepository.getMontantAReverserEtat();
        // La dette fournisseurs, elle, se rejoue à la date : elle est arrêtée au
        // dernier jour de la période, comme la trésorerie.
        BigDecimal dettesFournisseurs = facturePartenaireRepository.detteALaDate(fin);
        BigDecimal totalActif = tresorerie.add(creancesNettes).add(immobilisations);

        return EtatsCloture.builder()
                .cloturePeriodeId(cloture.getId())
                .annee(annee)
                .mois(mois)
                .produitsCaisse(caisse.getProduitsExploitation())
                .chargesVariables(caisse.getChargesVariables())
                .chargesFixes(caisse.getChargesFixes())
                .amortissements(caisse.getAmortissements())
                .dotationProvisions(dotation)
                .resultatCaisse(caisse.getResultatGestion())
                .produitsEngagement(engagement.getProduitsExploitation())
                .resultatEngagement(engagement.getResultatGestion())
                .pontCreances(caisse.getPontCreances())
                .tresorerie(tresorerie)
                .creancesChauffeurs(creances)
                .provisionCreances(provision)
                .creancesNettes(creancesNettes)
                .immobilisationsNettes(immobilisations)
                .totalActif(totalActif)
                .detteEtat(detteEtat)
                .dettesFournisseurs(dettesFournisseurs)
                .situationNette(totalActif.subtract(detteEtat).subtract(dettesFournisseurs))
                .soldes(soldes)
                .build();
    }
}
