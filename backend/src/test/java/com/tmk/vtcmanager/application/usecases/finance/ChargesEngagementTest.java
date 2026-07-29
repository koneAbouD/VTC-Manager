package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CompteResultat;
import com.tmk.vtcmanager.application.domain.finance.CompteResultat.BaseComptable;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import com.tmk.vtcmanager.application.ports.persistence.FactureFournisseurRepository;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import com.tmk.vtcmanager.application.services.DotationProvisionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Le cut-off des charges : une facture de mars réglée en avril pèse sur mars en
 * base engagement, et sur avril en base caisse. Sans jamais compter deux fois.
 */
class ChargesEngagementTest {

    private FinanceReportingRepository reportingRepository;
    private FactureFournisseurRepository factureRepository;
    private GetCompteResultatUseCase useCase;

    @BeforeEach
    void setUp() {
        reportingRepository = mock(FinanceReportingRepository.class);
        factureRepository = mock(FactureFournisseurRepository.class);
        EtatsClotureRepository etatsClotureRepository = mock(EtatsClotureRepository.class);
        GetProvisionCreancesUseCase provision = mock(GetProvisionCreancesUseCase.class);
        DotationProvisionService dotation = mock(DotationProvisionService.class);

        when(etatsClotureRepository.findByPeriode(anyInt(), anyInt())).thenReturn(Optional.empty());
        when(provision.executer()).thenReturn(
                com.tmk.vtcmanager.application.domain.finance.ProvisionCreances.builder()
                        .provisionTotale(BigDecimal.ZERO).build());
        when(dotation.calculer(any(), any())).thenReturn(BigDecimal.ZERO);
        when(reportingRepository.produitsEngagement(any(), any()))
                .thenReturn(BigDecimal.valueOf(1_000_000));
        when(reportingRepository.dotationAmortissements(any(), any())).thenReturn(BigDecimal.ZERO);

        useCase = new GetCompteResultatUseCase(reportingRepository, etatsClotureRepository,
                provision, dotation, factureRepository);
    }

    /**
     * Scénario : en mars, une facture de garage de 200 000 est reçue et rien
     * n'est payé. En avril, elle est réglée ; aucune facture nouvelle.
     */
    private void marsFactureRecue() {
        // Caisse de mars : aucune sortie.
        when(reportingRepository.totauxCaisseParNature(any(), any())).thenReturn(Map.of(
                "PRODUIT_EXPLOITATION", BigDecimal.valueOf(1_000_000)));
        when(reportingRepository.totauxCaisseHorsFactureParNature(any(), any()))
                .thenReturn(Map.of("PRODUIT_EXPLOITATION", BigDecimal.valueOf(1_000_000)));
        // Facture reçue en mars.
        when(factureRepository.chargesEngageesParNature(any(), any()))
                .thenReturn(Map.of("CHARGE_VARIABLE", BigDecimal.valueOf(200_000)));
    }

    private void avrilFactureReglee() {
        // Caisse d'avril : le règlement est bien sorti.
        when(reportingRepository.totauxCaisseParNature(any(), any())).thenReturn(Map.of(
                "PRODUIT_EXPLOITATION", BigDecimal.valueOf(1_000_000),
                "CHARGE_VARIABLE", BigDecimal.valueOf(200_000)));
        // …mais il porte le lien vers la facture : écarté de l'engagement.
        when(reportingRepository.totauxCaisseHorsFactureParNature(any(), any()))
                .thenReturn(Map.of("PRODUIT_EXPLOITATION", BigDecimal.valueOf(1_000_000)));
        // Aucune facture nouvelle en avril.
        when(factureRepository.chargesEngageesParNature(any(), any())).thenReturn(Map.of());
    }

    @Test
    @DisplayName("Mars, base engagement : la charge est là dès la réception de la facture")
    void mars_engagement_porte_la_charge() {
        marsFactureRecue();

        CompteResultat r = useCase.executer(2026, 3, BaseComptable.ENGAGEMENT);

        assertThat(r.getChargesVariables()).isEqualByComparingTo("200000");
        assertThat(r.getResultatGestion()).isEqualByComparingTo("800000");
    }

    @Test
    @DisplayName("Mars, base caisse : rien n'est sorti, donc aucune charge")
    void mars_caisse_ne_voit_rien() {
        marsFactureRecue();

        CompteResultat r = useCase.executer(2026, 3, BaseComptable.CAISSE);

        assertThat(r.getChargesVariables()).isEqualByComparingTo("0");
        assertThat(r.getResultatGestion()).isEqualByComparingTo("1000000");
    }

    @Test
    @DisplayName("Avril, base engagement : la charge n'est PAS recomptée au règlement")
    void avril_engagement_ne_recompte_pas() {
        avrilFactureReglee();

        CompteResultat r = useCase.executer(2026, 4, BaseComptable.ENGAGEMENT);

        assertThat(r.getChargesVariables()).isEqualByComparingTo("0");
        assertThat(r.getResultatGestion()).isEqualByComparingTo("1000000");
    }

    @Test
    @DisplayName("Avril, base caisse : la sortie d'argent apparaît bien")
    void avril_caisse_voit_la_sortie() {
        avrilFactureReglee();

        CompteResultat r = useCase.executer(2026, 4, BaseComptable.CAISSE);

        assertThat(r.getChargesVariables()).isEqualByComparingTo("200000");
        assertThat(r.getResultatGestion()).isEqualByComparingTo("800000");
    }

    @Test
    @DisplayName("Une dépense payée sans facture reste une charge dans les deux bases")
    void depense_sans_facture_comptee_partout() {
        when(reportingRepository.totauxCaisseParNature(any(), any())).thenReturn(Map.of(
                "PRODUIT_EXPLOITATION", BigDecimal.valueOf(1_000_000),
                "CHARGE_FIXE", BigDecimal.valueOf(75_000)));
        when(reportingRepository.totauxCaisseHorsFactureParNature(any(), any())).thenReturn(Map.of(
                "PRODUIT_EXPLOITATION", BigDecimal.valueOf(1_000_000),
                "CHARGE_FIXE", BigDecimal.valueOf(75_000)));
        when(factureRepository.chargesEngageesParNature(any(), any())).thenReturn(Map.of());

        assertThat(useCase.executer(2026, 5, BaseComptable.CAISSE).getChargesFixes())
                .isEqualByComparingTo("75000");
        assertThat(useCase.executer(2026, 5, BaseComptable.ENGAGEMENT).getChargesFixes())
                .isEqualByComparingTo("75000");
    }
}
