package com.tmk.vtcmanager.application.usecases.tableaubord;

import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat.BaseComptable;
import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.MargeVehicule;
import com.tmk.vtcmanager.application.domain.finance.ProvisionCreances;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import com.tmk.vtcmanager.application.usecases.etatparc.GetEtatParcUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetBalanceAgeeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetCompteResultatUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetMargesParVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.finance.GetProvisionCreancesUseCase;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcSummaryResponse;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.VehiculeExceptionDto;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.AlertesTableauBordDto;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.CashCreancesDto;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.DebiteurDto;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.PerformanceFlotteDto;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.PeriodeDto;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.PointSerieDto;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.SanteFinanciereDto;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.TableauBordResponse;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.VehiculePerformanceDto;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Assemble le tableau de bord de supervision.
 *
 * <p><b>Composition, pas recalcul.</b> Chaque chiffre vient de l'état qui en a
 * déjà la charge — compte de résultat, balance âgée, provision, marges par
 * véhicule, état de parc. Le tableau de bord n'y ajoute que les <em>ratios</em>
 * qui n'appartiennent à aucun de ces états parce qu'ils les croisent : le point
 * mort croise charges fixes et taux de marge, le DSO croise l'encours et les
 * produits, le manque à gagner croise les jours d'arrêt et le revenu journalier.
 * Un écart entre cet écran et les états détaillés serait donc un bug, jamais une
 * divergence de méthode.
 *
 * <p>Un mois clos sert ses chiffres archivés (le compte de résultat le fait
 * déjà) ; le mois en cours est marqué comme tel, pour qu'on ne lise pas ses
 * variations comme celles d'un mois plein.
 */
@RequiredArgsConstructor
public class GetTableauBordUseCase {

    /** Longueur de la courbe de tendance, en mois (mois courant compris). */
    private static final int MOIS_SERIE = 12;

    /** Au-delà, un arrêt n'est plus un aléa d'exploitation mais un dossier à traiter. */
    private static final int SEUIL_IMMOBILISATION_LONGUE_JOURS = 15;

    /** Taille des palmarès véhicules (meilleurs et moins bons). */
    private static final int TAILLE_PALMARES = 3;

    /** Nombre de débiteurs listés sous la balance âgée. */
    private static final int TAILLE_TOP_DEBITEURS = 5;

    private final GetCompteResultatUseCase getCompteResultatUseCase;
    private final GetMargesParVehiculeUseCase getMargesParVehiculeUseCase;
    private final GetBalanceAgeeUseCase getBalanceAgeeUseCase;
    private final GetProvisionCreancesUseCase getProvisionCreancesUseCase;
    private final GetEtatParcUseCase getEtatParcUseCase;
    private final CompteTresorerieRepository compteTresorerieRepository;
    private final CreanceRepository creanceRepository;
    private final FinanceReportingRepository financeReportingRepository;
    private final EtatsClotureRepository etatsClotureRepository;

    @Transactional(readOnly = true)
    public TableauBordResponse executer(int annee, int mois, BaseComptable base,
                                        Long groupeId, Long activiteId) {
        YearMonth periode = YearMonth.of(annee, mois);
        LocalDate today = LocalDate.now();
        boolean moisEnCours = periode.equals(YearMonth.from(today));

        // Un mois en cours ne compte que ses jours écoulés : diviser les produits
        // par 30 le 3 du mois donnerait un revenu journalier trois fois trop bas.
        int joursPeriode = periode.lengthOfMonth();
        int joursEcoules = moisEnCours ? today.getDayOfMonth()
                : (periode.isAfter(YearMonth.from(today)) ? 0 : joursPeriode);
        LocalDate arreteAu = moisEnCours ? today : periode.atEndOfMonth();

        CompteResultat resultat = getCompteResultatUseCase.executer(annee, mois, base);
        CompteResultat precedent = compteResultatPrecedent(periode, base);
        List<MargeVehicule> marges = getMargesParVehiculeUseCase.executer(annee, mois, base);
        EtatParcSummaryResponse parc = getEtatParcUseCase.execute(groupeId, activiteId);

        PeriodeDto periodeDto = new PeriodeDto(
                annee, mois, libellePeriode(periode), base.name(),
                joursEcoules, joursPeriode, moisEnCours,
                etatsClotureRepository.findByPeriode(annee, mois).isPresent(),
                arreteAu);

        return new TableauBordResponse(
                periodeDto,
                sante(resultat, precedent, periode),
                cash(resultat, joursEcoules),
                flotte(parc, resultat, marges, joursEcoules),
                alertes(parc));
    }

    // ─────────────────────────────────────────────────────────────────────
    // Bloc 1 — Santé financière
    // ─────────────────────────────────────────────────────────────────────

    private SanteFinanciereDto sante(CompteResultat r, CompteResultat precedent, YearMonth periode) {
        BigDecimal produits = nz(r.getProduitsExploitation());
        BigDecimal charges = nz(r.getChargesVariables()).add(nz(r.getChargesFixes()));

        BigDecimal tauxMarge = pourcentage(nz(r.getMargeSurCoutsVariables()), produits);

        // Point mort : le CA qui absorbe les charges fixes au taux de marge
        // constaté. Sans marge positive, aucun volume ne les couvre — la
        // question ne se pose pas, on ne sert pas un chiffre inventé.
        BigDecimal pointMort = null;
        BigDecimal couverture = null;
        if (tauxMarge != null && tauxMarge.compareTo(BigDecimal.ZERO) > 0) {
            pointMort = nz(r.getChargesFixes())
                    .divide(tauxMarge.divide(BigDecimal.valueOf(100), 6, RoundingMode.HALF_UP),
                            0, RoundingMode.HALF_UP);
            couverture = pourcentage(produits, pointMort);
        }

        return new SanteFinanciereDto(
                produits,
                nz(r.getChargesVariables()),
                nz(r.getMargeSurCoutsVariables()),
                nz(r.getChargesFixes()),
                nz(r.getExcedentBrutExploitation()),
                nz(r.getAmortissements()),
                nz(r.getDotationProvisions()),
                nz(r.getResultatGestion()),
                tauxMarge,
                pourcentage(charges, produits),
                pointMort,
                couverture,
                variation(produits, precedent == null ? null : precedent.getProduitsExploitation()),
                variation(nz(r.getResultatGestion()),
                        precedent == null ? null : precedent.getResultatGestion()),
                serie(periode));
    }

    /**
     * Mois précédent servi pour la seule variation : on le lit dans la même base
     * que le mois observé, sinon on comparerait deux mesures différentes.
     * Null quand le mois précédent n'existe pas encore dans les livres.
     */
    private CompteResultat compteResultatPrecedent(YearMonth periode, BaseComptable base) {
        YearMonth precedent = periode.minusMonths(1);
        return getCompteResultatUseCase.executer(precedent.getYear(), precedent.getMonthValue(), base);
    }

    /**
     * Courbe de tendance sur douze mois, lue directement dans l'agrégat caisse :
     * une tendance se lit sur des flux homogènes, et douze cascades complètes
     * (avec provisions et amortissements) coûteraient douze fois le prix pour un
     * dessin identique. Le résultat porté ici est donc un EBE.
     */
    private List<PointSerieDto> serie(YearMonth fin) {
        YearMonth debut = fin.minusMonths(MOIS_SERIE - 1L);
        return java.util.stream.IntStream.range(0, MOIS_SERIE)
                .mapToObj(debut::plusMonths)
                .map(m -> {
                    Map<String, BigDecimal> totaux = financeReportingRepository
                            .totauxCaisseParNature(m.atDay(1), m.atEndOfMonth());
                    BigDecimal produits = totaux.getOrDefault("PRODUIT_EXPLOITATION", BigDecimal.ZERO);
                    BigDecimal charges = totaux.getOrDefault("CHARGE_VARIABLE", BigDecimal.ZERO)
                            .add(totaux.getOrDefault("CHARGE_FIXE", BigDecimal.ZERO));
                    return new PointSerieDto(m.getYear(), m.getMonthValue(), libelleMoisCourt(m),
                            produits, charges, produits.subtract(charges));
                })
                .toList();
    }

    // ─────────────────────────────────────────────────────────────────────
    // Bloc 2 — Cash et créances
    // ─────────────────────────────────────────────────────────────────────

    private CashCreancesDto cash(CompteResultat r, int joursEcoules) {
        BigDecimal tresorerie = compteTresorerieRepository.findAllAvecSoldes(true).stream()
                .map(CompteAvecSolde::getSolde)
                .filter(java.util.Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<CreanceChauffeur> balance = getBalanceAgeeUseCase.executer();
        BigDecimal du0a7 = somme(balance, CreanceChauffeur::getDu0a7Jours);
        BigDecimal du8a30 = somme(balance, CreanceChauffeur::getDu8a30Jours);
        BigDecimal duPlus30 = somme(balance, CreanceChauffeur::getDuPlus30Jours);
        BigDecimal creances = somme(balance, CreanceChauffeur::getTotal);

        ProvisionCreances provision = getProvisionCreancesUseCase.executer();

        // Produits dus = encaissés + pont créances, quelle que soit la base lue :
        // le pont est par construction « engagement − caisse ».
        BigDecimal produitsCaisse = nz(r.getProduitsExploitation());
        BigDecimal pont = nz(r.getPontCreances());
        BigDecimal produitsDus = r.getBase() == BaseComptable.ENGAGEMENT
                ? produitsCaisse
                : produitsCaisse.add(pont);
        BigDecimal encaisse = r.getBase() == BaseComptable.ENGAGEMENT
                ? produitsCaisse.subtract(pont)
                : produitsCaisse;

        // DSO : l'encours ramené au produit journalier de la période. Sur un mois
        // sans production, le ratio n'a pas de sens — on ne le sert pas.
        BigDecimal dso = null;
        if (produitsDus.compareTo(BigDecimal.ZERO) > 0 && joursEcoules > 0) {
            BigDecimal parJour = produitsDus.divide(BigDecimal.valueOf(joursEcoules), 2, RoundingMode.HALF_UP);
            if (parJour.compareTo(BigDecimal.ZERO) > 0) {
                dso = creances.divide(parJour, 1, RoundingMode.HALF_UP);
            }
        }

        List<DebiteurDto> top = balance.stream()
                .sorted(Comparator.comparing(CreanceChauffeur::getTotal,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .limit(TAILLE_TOP_DEBITEURS)
                .map(c -> new DebiteurDto(c.getChauffeurId(), nomComplet(c), c.getNbLignes(),
                        nz(c.getTotal()), nz(c.getDuPlus30Jours())))
                .toList();

        return new CashCreancesDto(
                tresorerie,
                creances, du0a7, du8a30, duPlus30,
                pourcentage(duPlus30, creances),
                nz(provision.getProvisionTotale()),
                nz(provision.getCreancesNettes()),
                pourcentage(encaisse, produitsDus),
                produitsDus.subtract(encaisse),
                dso,
                nz(creanceRepository.getMontantAReverserEtat()),
                balance.size(),
                top);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Bloc 3 — Performance de la flotte
    // ─────────────────────────────────────────────────────────────────────

    private PerformanceFlotteDto flotte(EtatParcSummaryResponse parc, CompteResultat r,
                                        List<MargeVehicule> marges, int joursEcoules) {
        BigDecimal produits = nz(r.getProduitsExploitation());
        int parcActif = parc.parcActif();

        BigDecimal revenuParVehicule = parcActif > 0
                ? produits.divide(BigDecimal.valueOf(parcActif), 0, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        BigDecimal revenuJournalier = (parcActif > 0 && joursEcoules > 0)
                ? produits.divide(BigDecimal.valueOf((long) parcActif * joursEcoules), 0, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        long joursImmobilisation = marges.stream()
                .mapToLong(MargeVehicule::getJoursImmobilisation).sum();
        long joursParcTheoriques = (long) parcActif * joursEcoules;

        List<MargeVehicule> triees = marges.stream()
                .filter(m -> m.getMargeNette() != null)
                .sorted(Comparator.comparing(MargeVehicule::getMargeNette).reversed())
                .toList();
        BigDecimal margeNetteMoyenne = triees.isEmpty() ? BigDecimal.ZERO
                : triees.stream().map(MargeVehicule::getMargeNette)
                        .reduce(BigDecimal.ZERO, BigDecimal::add)
                        .divide(BigDecimal.valueOf(triees.size()), 0, RoundingMode.HALF_UP);

        return new PerformanceFlotteDto(
                parcActif, parc.enService(), parc.disponibles(),
                parc.enMaintenance(), parc.immobilises(), parc.horsParc(),
                parc.tauxDisponibilite(), parc.tauxUtilisation(),
                revenuParVehicule, revenuJournalier,
                joursImmobilisation,
                pourcentage(BigDecimal.valueOf(joursImmobilisation),
                        BigDecimal.valueOf(joursParcTheoriques)),
                revenuJournalier.multiply(BigDecimal.valueOf(joursImmobilisation)),
                margeNetteMoyenne,
                (int) triees.stream()
                        .filter(m -> m.getMargeNette().compareTo(BigDecimal.ZERO) < 0).count(),
                triees.size(),
                palmares(triees, true),
                palmares(triees, false));
    }

    /** Les [TAILLE_PALMARES] premiers ({@code meilleurs}) ou derniers d'une liste déjà triée. */
    private List<VehiculePerformanceDto> palmares(List<MargeVehicule> triees, boolean meilleurs) {
        if (triees.isEmpty()) return List.of();
        // Sur un parc plus petit que deux palmarès, les mêmes véhicules
        // figureraient en tête et en queue : on ne sert alors que le haut.
        if (!meilleurs && triees.size() <= TAILLE_PALMARES) return List.of();

        List<MargeVehicule> retenus = meilleurs
                ? triees.stream().limit(TAILLE_PALMARES).toList()
                : triees.reversed().stream().limit(TAILLE_PALMARES).toList();
        return retenus.stream()
                .map(m -> new VehiculePerformanceDto(m.getVehiculeId(), m.getImmatriculation(),
                        nz(m.getProduits()), nz(m.getMarge()), nz(m.getMargeNette()),
                        m.getJoursImmobilisation()))
                .toList();
    }

    // ─────────────────────────────────────────────────────────────────────
    // Bloc 4 — Alertes
    // ─────────────────────────────────────────────────────────────────────

    private AlertesTableauBordDto alertes(EtatParcSummaryResponse parc) {
        var a = parc.alertes();
        long longues = parc.exceptions().stream()
                .filter(e -> "IMMOBILISE".equals(e.statut()) || "EN_MAINTENANCE".equals(e.statut()))
                .filter(e -> e.joursDansStatut() != null
                        && e.joursDansStatut() > SEUIL_IMMOBILISATION_LONGUE_JOURS)
                .count();
        long sansChauffeur = parc.exceptions().stream()
                .filter(e -> "DISPONIBLE".equals(e.statut()))
                .map(VehiculeExceptionDto::vehiculeId)
                .distinct().count();

        return new AlertesTableauBordDto(
                a.documentsExpirantSous30Jours(), a.maintenancesDuesSous7Jours(),
                a.permisExpires(), a.vidangesDues(),
                (int) longues, (int) sansChauffeur);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Outils
    // ─────────────────────────────────────────────────────────────────────

    private static BigDecimal nz(BigDecimal valeur) {
        return valeur == null ? BigDecimal.ZERO : valeur;
    }

    private static BigDecimal somme(List<CreanceChauffeur> lignes,
                                    java.util.function.Function<CreanceChauffeur, BigDecimal> champ) {
        return lignes.stream().map(champ).filter(java.util.Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /** Ratio en %, arrondi au dixième. Null quand le dénominateur est nul : un
     * taux sans base n'est pas zéro, il n'existe pas. */
    private static BigDecimal pourcentage(BigDecimal numerateur, BigDecimal denominateur) {
        if (denominateur == null || denominateur.compareTo(BigDecimal.ZERO) == 0) return null;
        return nz(numerateur).multiply(BigDecimal.valueOf(100))
                .divide(denominateur.abs(), 1, RoundingMode.HALF_UP);
    }

    /**
     * Variation en % entre deux périodes. Partir de zéro n'a pas de taux de
     * croissance : on renvoie null plutôt qu'un « +100 % » qui ferait croire à
     * un doublement.
     */
    private static BigDecimal variation(BigDecimal courant, BigDecimal precedent) {
        if (precedent == null || precedent.compareTo(BigDecimal.ZERO) == 0) return null;
        return nz(courant).subtract(precedent)
                .divide(precedent.abs(), 4, RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(100))
                .setScale(1, RoundingMode.HALF_UP);
    }

    private static String nomComplet(CreanceChauffeur c) {
        String prenom = c.getChauffeurPrenom() == null ? "" : c.getChauffeurPrenom();
        String nom = c.getChauffeurNom() == null ? "" : c.getChauffeurNom();
        return (prenom + " " + nom).trim();
    }

    private static String libellePeriode(YearMonth periode) {
        String libelle = periode.format(DateTimeFormatter.ofPattern("MMMM yyyy", Locale.FRENCH));
        return libelle.substring(0, 1).toUpperCase(Locale.FRENCH) + libelle.substring(1);
    }

    private static String libelleMoisCourt(YearMonth periode) {
        return periode.format(DateTimeFormatter.ofPattern("MMM", Locale.FRENCH));
    }
}
