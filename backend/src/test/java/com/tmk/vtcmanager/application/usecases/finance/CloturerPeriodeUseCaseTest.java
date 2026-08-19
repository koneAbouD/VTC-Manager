package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.StatutImputationEcart;
import com.tmk.vtcmanager.application.exception.PeriodeNonCloturableException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import com.tmk.vtcmanager.application.services.DotationProvisionService;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.assertj.core.api.InstanceOfAssertFactories.throwable;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Clôture mensuelle : les contrôles préalables, et la photo des états qui doit
 * en sortir.
 */
class CloturerPeriodeUseCaseTest {

    /** Mois clos = le précédent, pour rester toujours « strictement passé ». */
    private static final YearMonth PERIODE = YearMonth.now().minusMonths(1);
    private static final int ANNEE = PERIODE.getYear();
    private static final int MOIS = PERIODE.getMonthValue();

    private CloturePeriodeRepository cloturePeriodeRepository;
    private ClotureCaisseRepository clotureCaisseRepository;
    private CompteTresorerieRepository compteTresorerieRepository;
    private CompteCourantRepository compteCourantRepository;
    private CreanceRepository creanceRepository;
    private FinanceReportingRepository reportingRepository;
    private EtatsClotureRepository etatsClotureRepository;
    private GetCompteResultatUseCase getCompteResultatUseCase;
    private GetProvisionCreancesUseCase getProvisionCreancesUseCase;
    private DotationProvisionService dotationProvisionService;
    private FacturePartenaireRepository facturePartenaireRepository;
    private CloturerPeriodeUseCase useCase;

    private final CompteTresorerie caisse = CompteTresorerie.builder()
            .id(1L).libelle("Caisse espèces").actif(true).build();

    @BeforeEach
    void setUp() {
        cloturePeriodeRepository = mock(CloturePeriodeRepository.class);
        clotureCaisseRepository = mock(ClotureCaisseRepository.class);
        compteTresorerieRepository = mock(CompteTresorerieRepository.class);
        compteCourantRepository = mock(CompteCourantRepository.class);
        when(compteCourantRepository.fondsCotisationsALaDate(any()))
                .thenReturn(BigDecimal.valueOf(120_000));
        creanceRepository = mock(CreanceRepository.class);
        reportingRepository = mock(FinanceReportingRepository.class);
        etatsClotureRepository = mock(EtatsClotureRepository.class);
        getCompteResultatUseCase = mock(GetCompteResultatUseCase.class);
        getProvisionCreancesUseCase = mock(GetProvisionCreancesUseCase.class);
        dotationProvisionService = mock(DotationProvisionService.class);
        facturePartenaireRepository = mock(FacturePartenaireRepository.class);
        when(facturePartenaireRepository.detteALaDate(any()))
                .thenReturn(BigDecimal.valueOf(80_000));
        when(dotationProvisionService.calculer(any(), any())).thenReturn(BigDecimal.valueOf(27_750));
        // La clôture lit la provision *à la date d'arrêté*, pas celle du jour.
        when(getProvisionCreancesUseCase.executer(any(java.time.LocalDate.class))).thenReturn(
                com.tmk.vtcmanager.application.domain.finance.ProvisionCreances.builder()
                        .creancesBrutes(BigDecimal.valueOf(769_000))
                        .provisionTotale(BigDecimal.valueOf(152_250))
                        .creancesNettes(BigDecimal.valueOf(616_750))
                        .build());

        when(cloturePeriodeRepository.existsByAnneeAndMois(anyInt(), anyInt())).thenReturn(false);
        when(cloturePeriodeRepository.findDerniere()).thenReturn(Optional.empty());
        when(cloturePeriodeRepository.save(any())).thenAnswer(inv -> {
            CloturePeriode c = inv.getArgument(0);
            c.setId(99L);
            return c;
        });

        when(compteTresorerieRepository.findByActifTrue()).thenReturn(List.of(caisse));
        when(compteTresorerieRepository.findAll()).thenReturn(List.of(caisse));
        when(compteTresorerieRepository.findAvecSoldeALaDate(anyLong(), any()))
                .thenReturn(Optional.of(CompteAvecSolde.builder()
                        .compte(caisse).solde(BigDecimal.valueOf(300_000)).build()));

        // Créances et dette État sont arrêtées au dernier jour du mois : ce sont
        // les variantes datées que la clôture doit interroger.
        when(creanceRepository.getBalanceAgeeALaDate(any())).thenReturn(List.of(
                CreanceChauffeur.builder().chauffeurId(1L)
                        .total(BigDecimal.valueOf(769_000)).build()));
        when(creanceRepository.getMontantAReverserEtatALaDate(any()))
                .thenReturn(BigDecimal.valueOf(50_000));
        when(reportingRepository.immobilisationsNettes(any())).thenReturn(BigDecimal.valueOf(2_000_000));

        when(getCompteResultatUseCase.executer(anyInt(), anyInt(), any()))
                .thenReturn(resultat(BigDecimal.valueOf(800_000)));

        caisseComptee(PERIODE.atDay(15), null);

        useCase = new CloturerPeriodeUseCase(cloturePeriodeRepository, clotureCaisseRepository,
                compteTresorerieRepository, compteCourantRepository, creanceRepository,
                reportingRepository, etatsClotureRepository, getCompteResultatUseCase,
                getProvisionCreancesUseCase, dotationProvisionService, facturePartenaireRepository);
    }

    private CompteResultat resultat(BigDecimal produits) {
        return resultat(produits, BigDecimal.valueOf(100_000), BigDecimal.valueOf(200_000));
    }

    private CompteResultat resultat(BigDecimal produits, BigDecimal chargesVariables,
                                    BigDecimal chargesFixes) {
        return CompteResultat.builder()
                .annee(ANNEE).mois(MOIS)
                .produitsExploitation(produits)
                .chargesVariables(chargesVariables)
                .chargesFixes(chargesFixes)
                .amortissements(BigDecimal.valueOf(50_000))
                .resultatGestion(BigDecimal.valueOf(450_000))
                .pontCreances(BigDecimal.valueOf(30_000))
                .build();
    }

    private void caisseComptee(LocalDate date, StatutImputationEcart imputation) {
        when(clotureCaisseRepository.findByCompteIdOrderByDateDesc(1L)).thenReturn(List.of(
                ClotureCaisse.builder()
                        .compteId(1L).dateCloture(date)
                        .ecart(imputation == null ? BigDecimal.ZERO : BigDecimal.valueOf(-4000))
                        .imputationStatut(imputation)
                        .build()));
    }

    @Test
    @DisplayName("Le mois courant ne se clôture pas")
    void mois_courant_refuse() {
        YearMonth courant = YearMonth.now();
        assertThatThrownBy(() -> useCase.executer(courant.getYear(), courant.getMonthValue()))
                .isInstanceOf(PeriodeNonCloturableException.class);
    }

    @Test
    @DisplayName("Une caisse non comptée dans le mois bloque la clôture")
    void caisse_non_comptee_bloque() {
        when(clotureCaisseRepository.findByCompteIdOrderByDateDesc(1L)).thenReturn(List.of());

        assertThatThrownBy(() -> useCase.executer(ANNEE, MOIS))
                .isInstanceOf(PeriodeNonCloturableException.class)
                .hasMessageContaining("Caisse espèces");
        verify(etatsClotureRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un écart de caisse en attente bloque la clôture")
    void ecart_en_attente_bloque() {
        caisseComptee(PERIODE.atDay(15), StatutImputationEcart.EN_ATTENTE);

        assertThatThrownBy(() -> useCase.executer(ANNEE, MOIS))
                .isInstanceOf(PeriodeNonCloturableException.class)
                .hasMessageContaining("imputation");
        verify(etatsClotureRepository, never()).save(any());
    }

    @Test
    @DisplayName("Tous les obstacles sont relevés d'un coup, pas seulement le premier")
    void obstacles_releves_ensemble() {
        CompteTresorerie mobileMoney = CompteTresorerie.builder()
                .id(2L).libelle("Orange Money").actif(true).build();
        when(compteTresorerieRepository.findByActifTrue())
                .thenReturn(List.of(caisse, mobileMoney));
        // La caisse a deux écarts pendants, le second compte n'a jamais été relevé.
        when(clotureCaisseRepository.findByCompteIdOrderByDateDesc(1L)).thenReturn(List.of(
                ClotureCaisse.builder().compteId(1L).dateCloture(PERIODE.atDay(12))
                        .ecart(BigDecimal.valueOf(-4000))
                        .imputationStatut(StatutImputationEcart.EN_ATTENTE).build(),
                ClotureCaisse.builder().compteId(1L).dateCloture(PERIODE.atDay(21))
                        .ecart(BigDecimal.valueOf(1500))
                        .imputationStatut(StatutImputationEcart.EN_ATTENTE).build()));
        when(clotureCaisseRepository.findByCompteIdOrderByDateDesc(2L)).thenReturn(List.of());

        // Les révéler un par un obligeait à relancer la clôture trois fois,
        // chaque essai n'en montrant qu'un.
        assertThatThrownBy(() -> useCase.executer(ANNEE, MOIS))
                .isInstanceOf(PeriodeNonCloturableException.class)
                .asInstanceOf(throwable(PeriodeNonCloturableException.class))
                .satisfies(ex -> {
                    assertThat(ex.getObstacles()).hasSize(3);
                    assertThat(ex.getObstacles().get(0)).contains("Caisse espèces");
                    assertThat(ex.getObstacles().get(2)).contains("Orange Money");
                    // Un comptage manquant l'emporte : il se règle dans la
                    // trésorerie, d'où les écarts se tranchent aussi.
                    assertThat(ex.getMotif())
                            .isEqualTo(PeriodeNonCloturableException.Motif.CAISSE_NON_COMPTEE);
                    assertThat(ex.getMessage()).contains("3 points");
                });
    }

    @Test
    @DisplayName("Le refus dit ce qui bloque : l'écran en tire l'action à proposer")
    void motif_porte_par_le_refus() {
        caisseComptee(PERIODE.atDay(15), StatutImputationEcart.EN_ATTENTE);

        assertThatThrownBy(() -> useCase.executer(ANNEE, MOIS))
                .asInstanceOf(throwable(PeriodeNonCloturableException.class))
                .satisfies(ex -> {
                    assertThat(ex.getMotif())
                            .isEqualTo(PeriodeNonCloturableException.Motif.ECART_NON_IMPUTE);
                    // Un seul obstacle : le message le reprend mot pour mot.
                    assertThat(ex.getObstacles()).hasSize(1);
                    assertThat(ex.getMessage()).isEqualTo(ex.getObstacles().get(0));
                });
    }

    @Test
    @DisplayName("Un mois déjà clôturé se distingue d'un mois non échu")
    void motifs_de_periode_distincts() {
        when(cloturePeriodeRepository.existsByAnneeAndMois(ANNEE, MOIS)).thenReturn(true);
        assertThatThrownBy(() -> useCase.executer(ANNEE, MOIS))
                .asInstanceOf(throwable(PeriodeNonCloturableException.class))
                .satisfies(ex -> assertThat(ex.getMotif())
                        .isEqualTo(PeriodeNonCloturableException.Motif.PERIODE_DEJA_CLOTUREE));

        YearMonth courant = YearMonth.now();
        assertThatThrownBy(() -> useCase.executer(courant.getYear(), courant.getMonthValue()))
                .asInstanceOf(throwable(PeriodeNonCloturableException.class))
                .satisfies(ex -> assertThat(ex.getMotif())
                        .isEqualTo(PeriodeNonCloturableException.Motif.MOIS_NON_ECHU));
    }

    @Test
    @DisplayName("Un comptage hors période ne compte pas comme un comptage du mois")
    void comptage_hors_periode_ne_compte_pas() {
        caisseComptee(PERIODE.plusMonths(1).atDay(3), null);

        assertThatThrownBy(() -> useCase.executer(ANNEE, MOIS))
                .isInstanceOf(PeriodeNonCloturableException.class);
    }

    @Test
    @DisplayName("La clôture archive les deux bases du résultat et le bilan")
    void archive_les_etats() {
        when(getCompteResultatUseCase.executer(ANNEE, MOIS, CompteResultat.BaseComptable.CAISSE))
                .thenReturn(resultat(BigDecimal.valueOf(800_000)));
        when(getCompteResultatUseCase.executer(ANNEE, MOIS, CompteResultat.BaseComptable.ENGAGEMENT))
                .thenReturn(resultat(BigDecimal.valueOf(830_000)));

        useCase.executer(ANNEE, MOIS);

        ArgumentCaptor<EtatsCloture> capture = ArgumentCaptor.forClass(EtatsCloture.class);
        verify(etatsClotureRepository).save(capture.capture());
        EtatsCloture e = capture.getValue();

        assertThat(e.getCloturePeriodeId()).isEqualTo(99L);
        assertThat(e.getAnnee()).isEqualTo(ANNEE);
        assertThat(e.getMois()).isEqualTo(MOIS);
        assertThat(e.getProduitsCaisse()).isEqualByComparingTo("800000");
        assertThat(e.getProduitsEngagement()).isEqualByComparingTo("830000");
        assertThat(e.getTresorerie()).isEqualByComparingTo("300000");
        assertThat(e.getImmobilisationsNettes()).isEqualByComparingTo("2000000");
        assertThat(e.getDetteEtat()).isEqualByComparingTo("50000");
        assertThat(e.getDotationProvisions()).isEqualByComparingTo("27750");
        assertThat(e.getSoldes()).hasSize(1);
        assertThat(e.getSoldes().get(0).getLibelleCompte()).isEqualTo("Caisse espèces");
    }

    @Test
    @DisplayName("Chaque solde archivé porte la date du comptage qui l'atteste")
    void archive_la_date_du_dernier_comptage() {
        LocalDate fin = YearMonth.of(ANNEE, MOIS).atEndOfMonth();
        LocalDate comptage = fin.minusDays(28);
        when(clotureCaisseRepository.findDerniereDateClotureALaDate(1L, fin))
                .thenReturn(Optional.of(comptage));

        useCase.executer(ANNEE, MOIS);

        ArgumentCaptor<EtatsCloture> capture = ArgumentCaptor.forClass(EtatsCloture.class);
        verify(etatsClotureRepository).save(capture.capture());

        // Le solde est arrêté au dernier jour du mois, mais la clôture n'exige
        // qu'un comptage tombant quelque part dans le mois : entre les deux
        // dates, personne n'a rien vérifié. La photo porte donc la date, et le
        // lecteur juge de l'écart plutôt que de croire le 31 attesté le 31.
        assertThat(capture.getValue().getSoldes().get(0).getDateDernierComptage())
                .isEqualTo(comptage);
    }

    @Test
    @DisplayName("Un compte jamais compté est archivé sans date d'attestation")
    void archive_sans_comptage() {
        useCase.executer(ANNEE, MOIS);

        ArgumentCaptor<EtatsCloture> capture = ArgumentCaptor.forClass(EtatsCloture.class);
        verify(etatsClotureRepository).save(capture.capture());

        // Nulle plutôt qu'inventée : la lecture affiche « aucun comptage ».
        assertThat(capture.getValue().getSoldes().get(0).getDateDernierComptage()).isNull();
    }

    @Test
    @DisplayName("Les charges des deux bases sont archivées séparément")
    void archive_les_charges_des_deux_bases() {
        when(getCompteResultatUseCase.executer(ANNEE, MOIS, CompteResultat.BaseComptable.CAISSE))
                .thenReturn(resultat(BigDecimal.valueOf(800_000)));
        // Une facture de 50 000 reçue dans le mois et non réglée : elle alourdit
        // les charges variables de l'engagement, pas celles de la caisse.
        when(getCompteResultatUseCase.executer(ANNEE, MOIS, CompteResultat.BaseComptable.ENGAGEMENT))
                .thenReturn(resultat(BigDecimal.valueOf(830_000),
                        BigDecimal.valueOf(150_000), BigDecimal.valueOf(200_000)));

        useCase.executer(ANNEE, MOIS);

        ArgumentCaptor<EtatsCloture> capture = ArgumentCaptor.forClass(EtatsCloture.class);
        verify(etatsClotureRepository).save(capture.capture());
        EtatsCloture e = capture.getValue();

        assertThat(e.getChargesVariables()).isEqualByComparingTo("100000");
        assertThat(e.getChargesVariablesEngagement()).isEqualByComparingTo("150000");
        assertThat(e.getChargesFixes()).isEqualByComparingTo("200000");
        assertThat(e.getChargesFixesEngagement()).isEqualByComparingTo("200000");
    }

    @Test
    @DisplayName("Le bilan archivé retient les créances nettes de provision, comme le bilan courant")
    void archive_les_creances_nettes() {
        useCase.executer(ANNEE, MOIS);

        ArgumentCaptor<EtatsCloture> capture = ArgumentCaptor.forClass(EtatsCloture.class);
        verify(etatsClotureRepository).save(capture.capture());
        EtatsCloture e = capture.getValue();

        // 769 000 brutes − 152 250 de provision (0 % / 25 % / 50 %) = 616 750.
        assertThat(e.getCreancesChauffeurs()).isEqualByComparingTo("769000");
        assertThat(e.getProvisionCreances()).isEqualByComparingTo("152250");
        // Actif = trésorerie + créances NETTES + immobilisations.
        assertThat(e.getTotalActif()).isEqualByComparingTo("2916750");
        assertThat(e.getDettesFournisseurs()).isEqualByComparingTo("80000");
        // Passif = État 50 000 + fournisseurs 80 000 + dépôts de cotisation 120 000.
        assertThat(e.getDepotsCotisations()).isEqualByComparingTo("120000");
        assertThat(e.getSituationNette()).isEqualByComparingTo("2666750");
    }

    @Test
    @DisplayName("Les dépôts de cotisation sont arrêtés au dernier jour du mois, bruts de créances")
    void depots_cotisations_arretes_a_la_fin_du_mois() {
        useCase.executer(ANNEE, MOIS);

        verify(compteCourantRepository).fondsCotisationsALaDate(PERIODE.atEndOfMonth());
        verify(compteCourantRepository, never()).getComptesCourantsParChauffeur();
    }

    @Test
    @DisplayName("La trésorerie archivée est arrêtée au dernier jour du mois")
    void tresorerie_arretee_a_la_fin_du_mois() {
        useCase.executer(ANNEE, MOIS);

        verify(compteTresorerieRepository).findAvecSoldeALaDate(1L, PERIODE.atEndOfMonth());
        verify(compteTresorerieRepository, never()).findAvecSoldeALaDate(eq(1L), eq(LocalDate.now()));
    }

    @Test
    @DisplayName("Rien n'est archivé si la clôture est refusée")
    void periode_deja_close_nrchive_rien() {
        when(cloturePeriodeRepository.existsByAnneeAndMois(ANNEE, MOIS)).thenReturn(true);

        assertThatThrownBy(() -> useCase.executer(ANNEE, MOIS))
                .isInstanceOf(PeriodeNonCloturableException.class);
        verify(etatsClotureRepository, never()).save(any());
        verify(compteTresorerieRepository, never()).findAllAvecSoldes(anyBoolean());
    }
}
