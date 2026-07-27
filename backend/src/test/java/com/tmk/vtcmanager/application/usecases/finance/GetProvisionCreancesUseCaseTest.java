package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.ProvisionCreances;
import com.tmk.vtcmanager.application.domain.parametre.ParametreGeneral;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.ParametreGeneralRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Dépréciation des créances : assiettes, taux paramétrés, arrondi au franc. */
class GetProvisionCreancesUseCaseTest {

    private CreanceRepository creanceRepository;
    private ParametreGeneralRepository parametreRepository;
    private GetProvisionCreancesUseCase useCase;

    @BeforeEach
    void setUp() {
        creanceRepository = mock(CreanceRepository.class);
        parametreRepository = mock(ParametreGeneralRepository.class);
        when(parametreRepository.findByCle(anyString())).thenReturn(Optional.empty());
        useCase = new GetProvisionCreancesUseCase(creanceRepository, parametreRepository);
    }

    private void taux(String cle, String valeur) {
        when(parametreRepository.findByCle(cle)).thenReturn(Optional.of(
                ParametreGeneral.builder().cle(cle).valeur(valeur).build()));
    }

    private void balance(long du0a7, long du8a30, long duPlus30) {
        when(creanceRepository.getBalanceAgee()).thenReturn(List.of(
                CreanceChauffeur.builder()
                        .chauffeurId(1L)
                        .du0a7Jours(BigDecimal.valueOf(du0a7))
                        .du8a30Jours(BigDecimal.valueOf(du8a30))
                        .duPlus30Jours(BigDecimal.valueOf(duPlus30))
                        .total(BigDecimal.valueOf(du0a7 + du8a30 + duPlus30))
                        .build()));
    }

    @Test
    @DisplayName("Taux par défaut : 0 % / 25 % / 50 %")
    void taux_par_defaut() {
        balance(230_000, 469_000, 70_000);

        ProvisionCreances p = useCase.executer();

        assertThat(p.getCreancesBrutes()).isEqualByComparingTo("769000");
        assertThat(p.getProvision0a7Jours()).isEqualByComparingTo("0");
        assertThat(p.getProvision8a30Jours()).isEqualByComparingTo("117250");
        assertThat(p.getProvisionPlus30Jours()).isEqualByComparingTo("35000");
        assertThat(p.getProvisionTotale()).isEqualByComparingTo("152250");
        assertThat(p.getCreancesNettes()).isEqualByComparingTo("616750");
    }

    @Test
    @DisplayName("Les taux paramétrés pilotent le calcul")
    void taux_parametres() {
        taux(GetProvisionCreancesUseCase.CLE_TAUX_8_30, "40");
        taux(GetProvisionCreancesUseCase.CLE_TAUX_PLUS_30, "100");
        balance(0, 100_000, 50_000);

        ProvisionCreances p = useCase.executer();

        assertThat(p.getProvision8a30Jours()).isEqualByComparingTo("40000");
        assertThat(p.getProvisionPlus30Jours()).isEqualByComparingTo("50000");
        assertThat(p.getProvisionTotale()).isEqualByComparingTo("90000");
    }

    @Test
    @DisplayName("Un taux illisible ne fait pas tomber le calcul : on garde le défaut")
    void taux_illisible_repli_sur_defaut() {
        taux(GetProvisionCreancesUseCase.CLE_TAUX_8_30, "vingt-cinq");
        balance(0, 100_000, 0);

        assertThat(useCase.executer().getProvision8a30Jours()).isEqualByComparingTo("25000");
    }

    @Test
    @DisplayName("La provision est arrondie au franc : le XOF n'a pas de centime")
    void arrondi_au_franc() {
        taux(GetProvisionCreancesUseCase.CLE_TAUX_8_30, "33");
        balance(0, 1_001, 0);

        // 1001 × 33 % = 330,33 → 330
        assertThat(useCase.executer().getProvision8a30Jours()).isEqualByComparingTo("330");
    }

    @Test
    @DisplayName("Sans créance, la provision est nulle et ne casse pas")
    void aucune_creance() {
        when(creanceRepository.getBalanceAgee()).thenReturn(List.of());

        ProvisionCreances p = useCase.executer();

        assertThat(p.getCreancesBrutes()).isEqualByComparingTo("0");
        assertThat(p.getProvisionTotale()).isEqualByComparingTo("0");
        assertThat(p.getCreancesNettes()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("Une tranche absente (null) est traitée comme zéro")
    void tranche_nulle_toleree() {
        when(creanceRepository.getBalanceAgee()).thenReturn(List.of(
                CreanceChauffeur.builder().chauffeurId(1L)
                        .du0a7Jours(null)
                        .du8a30Jours(BigDecimal.valueOf(40_000))
                        .duPlus30Jours(null)
                        .build()));

        assertThat(useCase.executer().getProvisionTotale()).isEqualByComparingTo("10000");
    }
}
