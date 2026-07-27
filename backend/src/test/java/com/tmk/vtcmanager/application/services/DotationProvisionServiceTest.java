package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;
import com.tmk.vtcmanager.application.ports.persistence.EtatsClotureRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Ce qui pèse sur le mois est la variation du stock de provision, pas le stock.
 */
class DotationProvisionServiceTest {

    private static final YearMonth MARS = YearMonth.of(2026, 3);

    private EtatsClotureRepository etatsClotureRepository;
    private DotationProvisionService service;

    @BeforeEach
    void setUp() {
        etatsClotureRepository = mock(EtatsClotureRepository.class);
        when(etatsClotureRepository.findByPeriode(anyInt(), anyInt())).thenReturn(Optional.empty());
        service = new DotationProvisionService(etatsClotureRepository);
    }

    private void provisionArchivee(YearMonth periode, String stock) {
        when(etatsClotureRepository.findByPeriode(periode.getYear(), periode.getMonthValue()))
                .thenReturn(Optional.of(EtatsCloture.builder()
                        .provisionCreances(stock == null ? null : new BigDecimal(stock))
                        .build()));
    }

    @Test
    @DisplayName("Premier mois exploité : la dotation est le stock entier")
    void premier_mois_constitue_la_provision() {
        assertThat(service.calculer(MARS, new BigDecimal("152250")))
                .isEqualByComparingTo("152250");
    }

    @Test
    @DisplayName("Le mois ne supporte que l'augmentation du stock")
    void seule_la_variation_pese() {
        provisionArchivee(MARS.minusMonths(1), "152250");

        assertThat(service.calculer(MARS, new BigDecimal("180000")))
                .isEqualByComparingTo("27750");
    }

    @Test
    @DisplayName("Les créances qui rentrent produisent une reprise, qui améliore le résultat")
    void reprise_quand_le_stock_baisse() {
        provisionArchivee(MARS.minusMonths(1), "180000");

        assertThat(service.calculer(MARS, new BigDecimal("120000")))
                .isEqualByComparingTo("-60000");
    }

    @Test
    @DisplayName("Un stock inchangé ne coûte rien au mois")
    void stock_stable_dotation_nulle() {
        provisionArchivee(MARS.minusMonths(1), "152250");

        assertThat(service.calculer(MARS, new BigDecimal("152250"))).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("Une photo antérieure sans provision est traitée comme un stock nul")
    void photo_ancienne_sans_provision() {
        provisionArchivee(MARS.minusMonths(1), null);

        assertThat(service.calculer(MARS, new BigDecimal("50000")))
                .isEqualByComparingTo("50000");
    }

    @Test
    @DisplayName("Le stock du mois précédent est cherché sur le bon mois, y compris à cheval sur l'année")
    void bascule_d_annee() {
        provisionArchivee(YearMonth.of(2025, 12), "90000");

        assertThat(service.calculer(YearMonth.of(2026, 1), new BigDecimal("100000")))
                .isEqualByComparingTo("10000");
    }
}
