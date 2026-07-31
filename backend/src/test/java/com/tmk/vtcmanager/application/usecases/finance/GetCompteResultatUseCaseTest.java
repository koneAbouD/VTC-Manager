package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat.BaseComptable;
import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import com.tmk.vtcmanager.application.services.DotationProvisionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Un mois clos sert sa photo ; un mois ouvert se recalcule. C'est ce qui rend
 * un état publié opposable : il ne change plus.
 */
class GetCompteResultatUseCaseTest {

    private FinanceReportingRepository reportingRepository;
    private EtatsClotureRepository etatsClotureRepository;
    private GetProvisionCreancesUseCase getProvisionCreancesUseCase;
    private DotationProvisionService dotationProvisionService;
    private FacturePartenaireRepository facturePartenaireRepository;
    private GetCompteResultatUseCase useCase;

    @BeforeEach
    void setUp() {
        reportingRepository = mock(FinanceReportingRepository.class);
        etatsClotureRepository = mock(EtatsClotureRepository.class);
        when(etatsClotureRepository.findByPeriode(anyInt(), anyInt())).thenReturn(Optional.empty());
        when(reportingRepository.totauxCaisseParNature(any(), any())).thenReturn(Map.of(
                "PRODUIT_EXPLOITATION", BigDecimal.valueOf(800_000),
                "CHARGE_VARIABLE", BigDecimal.valueOf(100_000),
                "CHARGE_FIXE", BigDecimal.valueOf(200_000)));
        when(reportingRepository.produitsEngagement(any(), any())).thenReturn(BigDecimal.valueOf(830_000));
        when(reportingRepository.dotationAmortissements(any(), any())).thenReturn(BigDecimal.valueOf(50_000));
        getProvisionCreancesUseCase = mock(GetProvisionCreancesUseCase.class);
        when(getProvisionCreancesUseCase.executer()).thenReturn(
                com.tmk.vtcmanager.application.domain.finance.ProvisionCreances.builder()
                        .provisionTotale(BigDecimal.valueOf(152_250)).build());
        dotationProvisionService = mock(DotationProvisionService.class);
        when(dotationProvisionService.calculer(any(), any())).thenReturn(BigDecimal.valueOf(20_000));

        facturePartenaireRepository = mock(FacturePartenaireRepository.class);
        when(facturePartenaireRepository.chargesEngageesParNature(any(), any()))
                .thenReturn(Map.of());
        when(reportingRepository.totauxCaisseHorsFactureParNature(any(), any()))
                .thenReturn(Map.of(
                        "CHARGE_VARIABLE", BigDecimal.valueOf(100_000),
                        "CHARGE_FIXE", BigDecimal.valueOf(200_000)));

        useCase = new GetCompteResultatUseCase(reportingRepository, etatsClotureRepository,
                getProvisionCreancesUseCase, dotationProvisionService,
                facturePartenaireRepository);
    }

    private EtatsCloture archive() {
        return EtatsCloture.builder()
                .annee(2026).mois(3)
                .produitsCaisse(BigDecimal.valueOf(500_000))
                .chargesVariables(BigDecimal.valueOf(80_000))
                .chargesFixes(BigDecimal.valueOf(120_000))
                .amortissements(BigDecimal.valueOf(40_000))
                .dotationProvisions(BigDecimal.valueOf(10_000))
                .resultatCaisse(BigDecimal.valueOf(250_000))
                .produitsEngagement(BigDecimal.valueOf(560_000))
                .resultatEngagement(BigDecimal.valueOf(320_000))
                .pontCreances(BigDecimal.valueOf(60_000))
                .build();
    }

    @Test
    @DisplayName("Mois ouvert : la cascade est recalculée")
    void mois_ouvert_recalcule() {
        CompteResultat r = useCase.executer(2026, 4, BaseComptable.CAISSE);

        assertThat(r.getProduitsExploitation()).isEqualByComparingTo("800000");
        assertThat(r.getMargeSurCoutsVariables()).isEqualByComparingTo("700000");
        assertThat(r.getExcedentBrutExploitation()).isEqualByComparingTo("500000");
        assertThat(r.getDotationProvisions()).isEqualByComparingTo("20000");
        assertThat(r.getResultatGestion()).isEqualByComparingTo("430000");
        assertThat(r.getPontCreances()).isEqualByComparingTo("30000");
    }

    @Test
    @DisplayName("Mois clos : la photo est servie, sans toucher aux agrégats")
    void mois_clos_sert_l_archive() {
        when(etatsClotureRepository.findByPeriode(2026, 3)).thenReturn(Optional.of(archive()));

        CompteResultat r = useCase.executer(2026, 3, BaseComptable.CAISSE);

        assertThat(r.getProduitsExploitation()).isEqualByComparingTo("500000");
        assertThat(r.getChargesVariables()).isEqualByComparingTo("80000");
        assertThat(r.getAmortissements()).isEqualByComparingTo("40000");
        // La cascade est reconstruite depuis les postes archivés.
        assertThat(r.getMargeSurCoutsVariables()).isEqualByComparingTo("420000");
        assertThat(r.getExcedentBrutExploitation()).isEqualByComparingTo("300000");
        assertThat(r.getDotationProvisions()).isEqualByComparingTo("10000");
        assertThat(r.getResultatGestion()).isEqualByComparingTo("250000");

        // Aucun recalcul : c'est la garantie que le chiffre publié ne bouge plus.
        verify(reportingRepository, never()).totauxCaisseParNature(any(), any());
        verify(reportingRepository, never()).produitsEngagement(any(), any());
        verify(reportingRepository, never()).dotationAmortissements(any(), any());
    }

    @Test
    @DisplayName("Mois clos, base engagement : les produits archivés de l'engagement sont repris")
    void mois_clos_base_engagement() {
        when(etatsClotureRepository.findByPeriode(2026, 3)).thenReturn(Optional.of(archive()));

        CompteResultat r = useCase.executer(2026, 3, BaseComptable.ENGAGEMENT);

        assertThat(r.getBase()).isEqualTo(BaseComptable.ENGAGEMENT);
        assertThat(r.getProduitsExploitation()).isEqualByComparingTo("560000");
        // 560 000 − 80 000 − 120 000 − 40 000 − 10 000
        assertThat(r.getResultatGestion()).isEqualByComparingTo("310000");
        assertThat(r.getPontCreances()).isEqualByComparingTo("60000");
    }

    @Test
    @DisplayName("Une donnée amont qui change ne modifie plus un mois clos")
    void amont_modifie_ne_change_pas_un_mois_clos() {
        when(etatsClotureRepository.findByPeriode(2026, 3)).thenReturn(Optional.of(archive()));

        BigDecimal avant = useCase.executer(2026, 3, BaseComptable.CAISSE).getResultatGestion();
        // Le barème d'amortissement est révisé : le recalcul donnerait autre chose.
        when(reportingRepository.dotationAmortissements(any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(BigDecimal.valueOf(999_999));
        BigDecimal apres = useCase.executer(2026, 3, BaseComptable.CAISSE).getResultatGestion();

        assertThat(apres).isEqualByComparingTo(avant);
    }
}
