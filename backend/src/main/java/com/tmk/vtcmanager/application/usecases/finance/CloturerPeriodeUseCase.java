package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.PeriodeNonCloturableException;
import com.tmk.vtcmanager.application.exception.PeriodeNonCloturableException.Motif;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
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
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

@RequiredArgsConstructor
public class CloturerPeriodeUseCase {

    /** Les dates lues par l'utilisateur s'écrivent comme il les écrit. */
    private static final DateTimeFormatter JOUR = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final CloturePeriodeRepository cloturePeriodeRepository;
    private final ClotureCaisseRepository clotureCaisseRepository;
    private final CompteTresorerieRepository compteTresorerieRepository;
    private final CompteCourantRepository compteCourantRepository;
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
            throw new PeriodeNonCloturableException(Motif.MOIS_NON_ECHU,
                    "Seul un mois strictement passé peut être clôturé");
        }
        if (cloturePeriodeRepository.existsByAnneeAndMois(annee, mois)) {
            throw new PeriodeNonCloturableException(Motif.PERIODE_DEJA_CLOTUREE,
                    "La période " + mois + "/" + annee + " est déjà clôturée");
        }
        cloturePeriodeRepository.findDerniere().ifPresent(derniere -> {
            YearMonth attendue = YearMonth.of(derniere.getAnnee(), derniere.getMois()).plusMonths(1);
            if (!periode.equals(attendue)) {
                throw new PeriodeNonCloturableException(Motif.PERIODE_NON_CONTIGUE,
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

    /**
     * Aucun compte laissé sans contrôle du solde réel, aucun écart laissé sans
     * décision. Le contrôle attendu dépend du support — comptage d'espèces,
     * relevé de l'opérateur mobile, rapprochement bancaire — et le message le
     * nomme pour ce qu'il est ({@link TypeCompteTresorerie#libelleControle()}).
     *
     * <p>Tous les manques sont relevés avant de refuser, pas seulement le
     * premier : s'arrêter au plus proche obligeait à relancer la clôture autant
     * de fois qu'il restait de comptages à faire, chaque essai n'en révélant
     * qu'un. L'utilisateur voit maintenant sa liste entière, la traite d'un
     * trait, et ne revient qu'une fois.
     */
    private void verifierCaisses(LocalDate debut, LocalDate fin) {
        List<String> obstacles = new ArrayList<>();
        boolean comptageManquant = false;

        for (CompteTresorerie compte : compteTresorerieRepository.findByActifTrue()) {
            List<ClotureCaisse> clotures =
                    clotureCaisseRepository.findByCompteIdOrderByDateDesc(compte.getId());
            String controle = compte.getType() != null
                    ? compte.getType().libelleControle() : "comptage";

            List<ClotureCaisse> duMois = clotures.stream()
                    .filter(c -> !c.getDateCloture().isBefore(debut)
                            && !c.getDateCloture().isAfter(fin))
                    .toList();

            if (duMois.isEmpty()) {
                String verbe = compte.getType() != null
                        ? compte.getType().verbeControle() : "comptez-le";
                comptageManquant = true;
                obstacles.add("Le compte « " + compte.getLibelle()
                        + " » n'a fait l'objet d'aucun " + controle + " sur la période : "
                        + verbe + " avant de clôturer le mois.");
                // Sans comptage dans le mois, il ne peut y avoir d'écart du mois
                // à trancher : rien de plus à relever sur ce compte.
                continue;
            }

            duMois.stream()
                    .filter(ClotureCaisse::attendImputation)
                    .forEach(c -> obstacles.add("L'écart constaté au " + controle
                            + " du " + JOUR.format(c.getDateCloture()) + " sur « "
                            + compte.getLibelle() + " » attend encore son imputation."));
        }

        if (obstacles.isEmpty()) return;

        // Le motif oriente l'écran vers l'action à proposer. Un comptage
        // manquant l'emporte : il se règle dans la trésorerie, d'où les écarts
        // se tranchent aussi.
        Motif motif = comptageManquant ? Motif.CAISSE_NON_COMPTEE : Motif.ECART_NON_IMPUTE;
        // Un seul obstacle parle mieux de lui-même que compté ; à plusieurs,
        // c'est le nombre qui renseigne, le détail suit dans la liste.
        String message = obstacles.size() == 1 ? obstacles.get(0)
                : obstacles.size() + " points restent à régler avant de figer le mois.";
        throw new PeriodeNonCloturableException(motif, message, obstacles);
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
                    // Jusqu'où ce solde est attesté. Le contrôle n'exige qu'un
                    // comptage quelque part dans le mois, alors que le solde est
                    // arrêté au dernier jour : entre les deux, personne n'a rien
                    // vérifié. La photo porte donc la date, et le lecteur juge
                    // de l'écart plutôt que de croire le 31 attesté le 31.
                    .dateDernierComptage(clotureCaisseRepository
                            .findDerniereDateClotureALaDate(compte.getId(), fin)
                            .orElse(null))
                    .build());
            tresorerie = tresorerie.add(solde);
        }

        // Créances et dette État : arrêtées au dernier jour du mois, comme la
        // trésorerie. Les prendre à l'instant de la clôture — souvent plusieurs
        // jours après la fin du mois — ferait entrer à l'actif des mouvements
        // du mois suivant, et l'actif archivé n'existerait à aucune date réelle.
        BigDecimal creances = creanceRepository.getBalanceAgeeALaDate(fin).stream()
                .map(CreanceChauffeur::getTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        // C'est le net de dépréciation qui entre à l'actif ; la dépréciation est
        // elle aussi appréciée à la date d'arrêté, sur la même balance.
        BigDecimal provision = getProvisionCreancesUseCase.executer(fin).getProvisionTotale();
        BigDecimal creancesNettes = creances.subtract(provision);
        // Ce que le mois supporte : la variation par rapport à la photo du mois
        // précédent, pas le stock.
        BigDecimal dotation = dotationProvisionService.calculer(
                YearMonth.of(annee, mois), provision);

        BigDecimal immobilisations = reportingRepository.immobilisationsNettes(fin);
        BigDecimal detteEtat = creanceRepository.getMontantAReverserEtatALaDate(fin);
        // La dette fournisseurs, elle, se rejoue à la date : elle est arrêtée au
        // dernier jour de la période, comme la trésorerie.
        BigDecimal dettesFournisseurs = facturePartenaireRepository.detteALaDate(fin);
        // Les dépôts de cotisation se rejouent aussi : une cotisation restituée
        // depuis était bien détenue au dernier jour du mois clôturé.
        BigDecimal depotsCotisations = compteCourantRepository.fondsCotisationsALaDate(fin);

        BigDecimal totalActif = tresorerie.add(creancesNettes).add(immobilisations);
        BigDecimal totalDettes = detteEtat.add(dettesFournisseurs).add(depotsCotisations);

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
                // Les charges des deux bases sont archivées séparément : une
                // facture reçue et non réglée dans le mois pèse sur l'engagement
                // et pas sur la caisse. Croiser les deux jeux ferait diverger le
                // mois relu du résultat publié.
                .chargesVariablesEngagement(engagement.getChargesVariables())
                .chargesFixesEngagement(engagement.getChargesFixes())
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
                .depotsCotisations(depotsCotisations)
                .situationNette(totalActif.subtract(totalDettes))
                .soldes(soldes)
                .build();
    }
}
