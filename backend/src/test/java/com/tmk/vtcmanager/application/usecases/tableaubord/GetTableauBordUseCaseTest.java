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
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcAlertesDto;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcSummaryResponse;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.VehiculeExceptionDto;
import com.tmk.vtcmanager.interfaces.rest.tableaubord.dto.TableauBordResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GetTableauBordUseCaseTest {

    private GetCompteResultatUseCase compteResultat;
    private GetMargesParVehiculeUseCase marges;
    private GetBalanceAgeeUseCase balanceAgee;
    private GetProvisionCreancesUseCase provision;
    private GetEtatParcUseCase etatParc;
    private CompteTresorerieRepository compteTresorerieRepository;
    private CreanceRepository creanceRepository;
    private FinanceReportingRepository reportingRepository;
    private EtatsClotureRepository etatsClotureRepository;
    private GetTableauBordUseCase useCase;

    private static final int ANNEE = 2026;
    private static final int MOIS = 5;

    @BeforeEach
    void setUp() {
        compteResultat = mock(GetCompteResultatUseCase.class);
        marges = mock(GetMargesParVehiculeUseCase.class);
        balanceAgee = mock(GetBalanceAgeeUseCase.class);
        provision = mock(GetProvisionCreancesUseCase.class);
        etatParc = mock(GetEtatParcUseCase.class);
        compteTresorerieRepository = mock(CompteTresorerieRepository.class);
        creanceRepository = mock(CreanceRepository.class);
        reportingRepository = mock(FinanceReportingRepository.class);
        etatsClotureRepository = mock(EtatsClotureRepository.class);

        useCase = new GetTableauBordUseCase(compteResultat, marges, balanceAgee,
                provision, etatParc, compteTresorerieRepository, creanceRepository,
                reportingRepository, etatsClotureRepository);

        // Valeurs par défaut : chaque test ne renseigne que ce qu'il éprouve.
        when(compteResultat.executer(anyInt(), anyInt(), any())).thenReturn(resultat(
                "1000000", "400000", "300000", "0"));
        when(marges.executer(anyInt(), anyInt(), any())).thenReturn(List.of());
        when(balanceAgee.executer()).thenReturn(List.of());
        when(provision.executer()).thenReturn(ProvisionCreances.builder()
                .provisionTotale(BigDecimal.ZERO).creancesNettes(BigDecimal.ZERO).build());
        when(etatParc.execute(any(), any())).thenReturn(parc(10, 7, 1, 1, 1));
        when(compteTresorerieRepository.findAllAvecSoldes(true)).thenReturn(List.of());
        when(creanceRepository.getMontantAReverserEtat()).thenReturn(BigDecimal.ZERO);
        when(reportingRepository.totauxCaisseParNature(any(), any())).thenReturn(Map.of());
        when(etatsClotureRepository.findByPeriode(anyInt(), anyInt())).thenReturn(Optional.empty());
    }

    // ── Bloc finance ────────────────────────────────────────────────────

    @Test
    void calcule_le_taux_de_marge_et_le_point_mort() {
        // Produits 1 000 000, charges variables 400 000 → marge 600 000 (60 %).
        // Charges fixes 300 000 → point mort = 300 000 / 0,60 = 500 000.
        var res = executer();

        assertThat(res.finance().tauxMargeVariable()).isEqualByComparingTo("60.0");
        assertThat(res.finance().pointMort()).isEqualByComparingTo("500000");
        // Produits 1 000 000 pour un point mort de 500 000 : couvert à 200 %.
        assertThat(res.finance().tauxCouverturePointMort()).isEqualByComparingTo("200.0");
        assertThat(res.finance().tauxCharges()).isEqualByComparingTo("70.0");
    }

    @Test
    void ne_sert_pas_de_point_mort_quand_la_marge_est_negative() {
        // Charges variables au-dessus des produits : aucun volume ne couvre les
        // charges fixes — servir un chiffre serait mentir.
        when(compteResultat.executer(anyInt(), anyInt(), any()))
                .thenReturn(resultat("100000", "150000", "50000", "0"));

        var res = executer();

        assertThat(res.finance().pointMort()).isNull();
        assertThat(res.finance().tauxCouverturePointMort()).isNull();
    }

    @Test
    void ne_sert_aucun_ratio_quand_la_periode_est_vide() {
        when(compteResultat.executer(anyInt(), anyInt(), any()))
                .thenReturn(resultat("0", "0", "0", "0"));

        var res = executer();

        assertThat(res.finance().tauxMargeVariable()).isNull();
        assertThat(res.finance().tauxCharges()).isNull();
        assertThat(res.finance().produits()).isEqualByComparingTo("0");
    }

    @Test
    void construit_une_serie_de_douze_mois_terminee_par_la_periode_lue() {
        when(reportingRepository.totauxCaisseParNature(any(), any())).thenReturn(Map.of(
                "PRODUIT_EXPLOITATION", new BigDecimal("500000"),
                "CHARGE_VARIABLE", new BigDecimal("200000"),
                "CHARGE_FIXE", new BigDecimal("100000")));

        var serie = executer().finance().serie();

        assertThat(serie).hasSize(12);
        assertThat(serie.getLast().annee()).isEqualTo(ANNEE);
        assertThat(serie.getLast().mois()).isEqualTo(MOIS);
        assertThat(serie.getFirst().mois()).isEqualTo(YearMonth.of(ANNEE, MOIS)
                .minusMonths(11).getMonthValue());
        assertThat(serie.getLast().resultat()).isEqualByComparingTo("200000");
    }

    @Test
    void ne_sert_pas_de_variation_quand_le_mois_precedent_est_vide() {
        // Partir de zéro n'a pas de taux de croissance : « +100 % » ferait
        // croire à un doublement.
        when(compteResultat.executer(ANNEE, MOIS, BaseComptable.CAISSE))
                .thenReturn(resultat("800000", "0", "0", "0"));
        when(compteResultat.executer(ANNEE, MOIS - 1, BaseComptable.CAISSE))
                .thenReturn(resultat("0", "0", "0", "0"));

        var res = executer();

        assertThat(res.finance().variationProduitsPct()).isNull();
        assertThat(res.finance().variationResultatPct()).isNull();
    }

    // ── Bloc cash ───────────────────────────────────────────────────────

    @Test
    void somme_les_soldes_des_comptes_actifs() {
        when(compteTresorerieRepository.findAllAvecSoldes(true)).thenReturn(List.of(
                CompteAvecSolde.builder().solde(new BigDecimal("250000")).build(),
                CompteAvecSolde.builder().solde(new BigDecimal("75000")).build(),
                CompteAvecSolde.builder().solde(null).build()));

        assertThat(executer().cash().tresorerieDisponible())
                .isEqualByComparingTo("325000");
    }

    @Test
    void agrege_la_balance_agee_et_isole_la_part_ancienne() {
        when(balanceAgee.executer()).thenReturn(List.of(
                creance(1L, "Kone", "Ali", "50000", "30000", "20000"),
                creance(2L, "Traore", "Awa", "10000", "0", "80000")));

        var cash = executer().cash();

        assertThat(cash.creancesBrutes()).isEqualByComparingTo("190000");
        assertThat(cash.creances0a7Jours()).isEqualByComparingTo("60000");
        assertThat(cash.creances8a30Jours()).isEqualByComparingTo("30000");
        assertThat(cash.creancesPlus30Jours()).isEqualByComparingTo("100000");
        // 100 000 / 190 000 = 52,6 %.
        assertThat(cash.partCreancesRisque()).isEqualByComparingTo("52.6");
        assertThat(cash.nbChauffeursDebiteurs()).isEqualTo(2);
        // Palmarès trié par total décroissant : Traore (90 000) devant Kone (100 000)…
        assertThat(cash.topDebiteurs()).extracting("nom")
                .containsExactly("Ali Kone", "Awa Traore");
    }

    @Test
    void deduit_le_taux_de_recouvrement_du_pont_creances_en_base_caisse() {
        // Encaissé 800 000, pont créances 200 000 → dû 1 000 000, recouvré 80 %.
        when(compteResultat.executer(anyInt(), anyInt(), any()))
                .thenReturn(resultat("800000", "0", "0", "200000"));

        var cash = executer().cash();

        assertThat(cash.tauxRecouvrement()).isEqualByComparingTo("80.0");
        assertThat(cash.resteAEncaisserPeriode()).isEqualByComparingTo("200000");
    }

    @Test
    void deduit_le_taux_de_recouvrement_en_base_engagement() {
        // En base engagement, les produits servis sont déjà les produits dus :
        // l'encaissé s'en déduit en retranchant le pont.
        var lu = resultat("1000000", "0", "0", "250000");
        lu.setBase(BaseComptable.ENGAGEMENT);
        when(compteResultat.executer(anyInt(), anyInt(), any())).thenReturn(lu);

        var cash = useCase.executer(ANNEE, MOIS, BaseComptable.ENGAGEMENT, null, null).cash();

        assertThat(cash.tauxRecouvrement()).isEqualByComparingTo("75.0");
        assertThat(cash.resteAEncaisserPeriode()).isEqualByComparingTo("250000");
    }

    @Test
    void calcule_le_dso_sur_les_jours_de_la_periode() {
        // Mois passé complet : 31 jours en mai. Dû 1 000 000 → 32 258,06 / jour.
        // Encours 500 000 → 15,5 jours de production.
        when(compteResultat.executer(anyInt(), anyInt(), any()))
                .thenReturn(resultat("1000000", "0", "0", "0"));
        when(balanceAgee.executer()).thenReturn(List.of(
                creance(1L, "Kone", "Ali", "500000", "0", "0")));

        assertThat(executer().cash().dso()).isEqualByComparingTo("15.5");
    }

    @Test
    void ne_sert_pas_de_dso_sans_production() {
        when(compteResultat.executer(anyInt(), anyInt(), any()))
                .thenReturn(resultat("0", "0", "0", "0"));
        when(balanceAgee.executer()).thenReturn(List.of(
                creance(1L, "Kone", "Ali", "500000", "0", "0")));

        assertThat(executer().cash().dso()).isNull();
    }

    // ── Bloc flotte ─────────────────────────────────────────────────────

    @Test
    void valorise_les_jours_d_arret_au_revenu_journalier_moyen() {
        // 10 véhicules actifs × 31 jours = 310 jours-parc ; produits 1 000 000
        // → 3 226 / jour-véhicule. 20 jours d'arrêt → 64 520 de manque à gagner.
        when(marges.executer(anyInt(), anyInt(), any())).thenReturn(List.of(
                marge(1L, "AA-001", "600000", "150000", 12),
                marge(2L, "AA-002", "400000", "-50000", 8)));

        var flotte = executer().flotte();

        assertThat(flotte.revenuParVehiculeActif()).isEqualByComparingTo("100000");
        assertThat(flotte.revenuJournalierMoyen()).isEqualByComparingTo("3226");
        assertThat(flotte.joursImmobilisation()).isEqualTo(20);
        // 20 / 310 = 6,5 %.
        assertThat(flotte.tauxImmobilisation()).isEqualByComparingTo("6.5");
        assertThat(flotte.manqueAGagnerImmobilisation()).isEqualByComparingTo("64520");
    }

    @Test
    void compte_les_vehicules_deficitaires_et_moyenne_les_marges_nettes() {
        when(marges.executer(anyInt(), anyInt(), any())).thenReturn(List.of(
                marge(1L, "AA-001", "600000", "150000", 0),
                marge(2L, "AA-002", "400000", "-50000", 0),
                marge(3L, "AA-003", "500000", "50000", 0)));

        var flotte = executer().flotte();

        assertThat(flotte.nbVehiculesDeficitaires()).isEqualTo(1);
        assertThat(flotte.nbVehiculesEvalues()).isEqualTo(3);
        // (150 000 − 50 000 + 50 000) / 3 = 50 000.
        assertThat(flotte.margeNetteMoyenne()).isEqualByComparingTo("50000");
    }

    @Test
    void classe_les_vehicules_du_meilleur_au_moins_bon() {
        when(marges.executer(anyInt(), anyInt(), any())).thenReturn(List.of(
                marge(1L, "AA-001", "100000", "10000", 0),
                marge(2L, "AA-002", "100000", "90000", 0),
                marge(3L, "AA-003", "100000", "50000", 0),
                marge(4L, "AA-004", "100000", "-20000", 0),
                marge(5L, "AA-005", "100000", "70000", 0),
                marge(6L, "AA-006", "100000", "30000", 0),
                marge(7L, "AA-007", "100000", "5000", 0)));

        var flotte = executer().flotte();

        assertThat(flotte.meilleurs()).extracting("immatriculation")
                .containsExactly("AA-002", "AA-005", "AA-003");
        assertThat(flotte.moinsBons()).extracting("immatriculation")
                .containsExactly("AA-004", "AA-007", "AA-001");
    }

    @Test
    void n_affiche_pas_de_palmares_des_moins_bons_sur_un_parc_trop_petit() {
        // Trois véhicules ou moins : les mêmes figureraient en tête et en queue.
        when(marges.executer(anyInt(), anyInt(), any())).thenReturn(List.of(
                marge(1L, "AA-001", "100000", "10000", 0),
                marge(2L, "AA-002", "100000", "90000", 0)));

        var flotte = executer().flotte();

        assertThat(flotte.meilleurs()).hasSize(2);
        assertThat(flotte.moinsBons()).isEmpty();
    }

    // ── Bloc alertes et cadrage ─────────────────────────────────────────

    @Test
    void distingue_les_arrets_longs_des_vehicules_sans_chauffeur() {
        when(etatParc.execute(any(), any())).thenReturn(new EtatParcSummaryResponse(
                10, 10, 5, 2, 1, 2, 0,
                new BigDecimal("70.0"), new BigDecimal("50.0"),
                List.of(
                        exception(1L, "IMMOBILISE", 40L),
                        exception(2L, "IMMOBILISE", 3L),
                        exception(3L, "EN_MAINTENANCE", 20L),
                        exception(4L, "DISPONIBLE", 5L),
                        exception(5L, "DISPONIBLE", 1L)),
                new EtatParcAlertesDto(3, 2, 1, 4)));

        var alertes = executer().alertes();

        assertThat(alertes.immobilisationsLongues()).isEqualTo(2);
        assertThat(alertes.vehiculesSansChauffeur()).isEqualTo(2);
        assertThat(alertes.documentsExpirantSous30Jours()).isEqualTo(3);
        assertThat(alertes.vidangesDues()).isEqualTo(4);
    }

    @Test
    void signale_une_periode_close() {
        when(etatsClotureRepository.findByPeriode(ANNEE, MOIS))
                .thenReturn(Optional.of(mock(
                        com.tmk.vtcmanager.application.domain.finance.EtatsCloture.class)));

        var periode = executer().periode();

        assertThat(periode.cloture()).isTrue();
        assertThat(periode.moisEnCours()).isFalse();
        assertThat(periode.joursPeriode()).isEqualTo(31);
        assertThat(periode.joursEcoules()).isEqualTo(31);
        assertThat(periode.label()).isEqualTo("Mai 2026");
        assertThat(periode.base()).isEqualTo("CAISSE");
    }

    @Test
    void ne_compte_que_les_jours_ecoules_du_mois_en_cours() {
        // Un mois en cours n'a pas encore livré tous ses jours : diviser par la
        // longueur du mois écraserait toutes les moyennes journalières.
        LocalDate today = LocalDate.now();

        var periode = useCase.executer(today.getYear(), today.getMonthValue(),
                BaseComptable.CAISSE, null, null).periode();

        assertThat(periode.moisEnCours()).isTrue();
        assertThat(periode.joursEcoules()).isEqualTo(today.getDayOfMonth());
        assertThat(periode.arreteAu()).isEqualTo(today);
    }

    // ── Fabriques ───────────────────────────────────────────────────────

    private TableauBordResponse executer() {
        return useCase.executer(ANNEE, MOIS, BaseComptable.CAISSE, null, null);
    }

    private static CompteResultat resultat(String produits, String chargesVariables,
                                           String chargesFixes, String pont) {
        BigDecimal p = new BigDecimal(produits);
        BigDecimal cv = new BigDecimal(chargesVariables);
        BigDecimal cf = new BigDecimal(chargesFixes);
        BigDecimal marge = p.subtract(cv);
        BigDecimal ebe = marge.subtract(cf);
        return CompteResultat.builder()
                .annee(ANNEE).mois(MOIS).base(BaseComptable.CAISSE)
                .produitsExploitation(p)
                .chargesVariables(cv)
                .margeSurCoutsVariables(marge)
                .chargesFixes(cf)
                .excedentBrutExploitation(ebe)
                .amortissements(BigDecimal.ZERO)
                .dotationProvisions(BigDecimal.ZERO)
                .resultatGestion(ebe)
                .pontCreances(new BigDecimal(pont))
                .build();
    }

    private static CreanceChauffeur creance(Long id, String nom, String prenom,
                                            String du0a7, String du8a30, String plus30) {
        BigDecimal a = new BigDecimal(du0a7);
        BigDecimal b = new BigDecimal(du8a30);
        BigDecimal c = new BigDecimal(plus30);
        return CreanceChauffeur.builder()
                .chauffeurId(id).chauffeurNom(nom).chauffeurPrenom(prenom)
                .nbLignes(2)
                .du0a7Jours(a).du8a30Jours(b).duPlus30Jours(c)
                .total(a.add(b).add(c))
                .build();
    }

    private static MargeVehicule marge(Long id, String immat, String produits,
                                       String margeNette, long joursArret) {
        return MargeVehicule.builder()
                .vehiculeId(id).immatriculation(immat)
                .produits(new BigDecimal(produits))
                .chargesVariables(BigDecimal.ZERO)
                .marge(new BigDecimal(margeNette))
                .dotationAmortissement(BigDecimal.ZERO)
                .margeNette(new BigDecimal(margeNette))
                .joursImmobilisation(joursArret)
                .build();
    }

    private static EtatParcSummaryResponse parc(int total, int enService, int disponibles,
                                                int enMaintenance, int immobilises) {
        return new EtatParcSummaryResponse(total, total, enService, disponibles,
                enMaintenance, immobilises, 0,
                new BigDecimal("80.0"), new BigDecimal("70.0"),
                List.of(), new EtatParcAlertesDto(0, 0, 0, 0));
    }

    private static VehiculeExceptionDto exception(Long id, String statut, Long jours) {
        return new VehiculeExceptionDto(id, "AA-00" + id, "Véhicule " + id,
                statut, "PANNE_OU_ACCIDENT", jours, null, null, null, null);
    }
}
