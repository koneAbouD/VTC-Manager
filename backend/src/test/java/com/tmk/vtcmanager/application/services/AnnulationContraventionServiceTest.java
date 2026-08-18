package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Extourner l'écriture qui réglait une contravention doit rendre celle-ci à
 * l'état où le versement l'avait trouvée. Sans cela, une amende resterait PAYE
 * alors que le chauffeur n'a plus rien versé : elle sortirait des relances sans
 * avoir été honorée.
 */
class AnnulationContraventionServiceTest {

    private static final Long CONTRAVENTION_ID = 42L;

    private ContraventionRepository contraventionRepository;
    private AnnulationContraventionService service;

    @BeforeEach
    void setUp() {
        contraventionRepository = mock(ContraventionRepository.class);
        when(contraventionRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        service = new AnnulationContraventionService(contraventionRepository);
    }

    private OperationFinanciere ecriture(String montant) {
        return OperationFinanciere.builder()
                .id(1L)
                .contraventionId(CONTRAVENTION_ID)
                .montant(new BigDecimal(montant))
                .build();
    }

    private Contravention contravention(String montant, String paye, ContraventionStatus statut) {
        Contravention c = Contravention.builder()
                .id(CONTRAVENTION_ID)
                .montant(new BigDecimal(montant))
                .montantPaye(new BigDecimal(paye))
                .statut(statut)
                .build();
        when(contraventionRepository.findById(CONTRAVENTION_ID)).thenReturn(Optional.of(c));
        return c;
    }

    @Test
    @DisplayName("Un règlement intégral extourné rend la contravention EN_ATTENTE")
    void reglement_integral_extourne() {
        Contravention c = contravention("50000", "50000", ContraventionStatus.PAYE);

        service.annulerPaiementLie(ecriture("50000"));

        assertThat(c.getStatut()).isEqualTo(ContraventionStatus.EN_ATTENTE);
        assertThat(c.getMontantPaye()).isEqualByComparingTo("0");
        assertThat(c.getDatePaiement()).isNull();
        verify(contraventionRepository).save(c);
    }

    @Test
    @DisplayName("Il reste un versement : la contravention repasse PARTIELLEMENT_PAYE")
    void reste_un_versement() {
        Contravention c = contravention("50000", "50000", ContraventionStatus.PAYE);

        service.annulerPaiementLie(ecriture("20000"));

        assertThat(c.getStatut()).isEqualTo(ContraventionStatus.PARTIELLEMENT_PAYE);
        assertThat(c.getMontantPaye()).isEqualByComparingTo("30000");
    }

    @Test
    @DisplayName("Une contravention reversée à l'État garde son statut, seul le versé baisse")
    void contravention_reversee() {
        Contravention c = contravention("50000", "50000", ContraventionStatus.REVERSE);

        service.annulerPaiementLie(ecriture("50000"));

        assertThat(c.getStatut()).isEqualTo(ContraventionStatus.REVERSE);
        assertThat(c.getMontantPaye()).isEqualByComparingTo("0");
    }

    @Test
    @DisplayName("Une écriture sans contravention liée ne fait rien")
    void ecriture_sans_lien() {
        service.annulerPaiementLie(OperationFinanciere.builder().id(1L).build());
        service.annulerPaiementLie(null);

        verify(contraventionRepository, never()).findById(anyLong());
        verify(contraventionRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une contravention introuvable est ignorée sans erreur")
    void contravention_introuvable() {
        when(contraventionRepository.findById(CONTRAVENTION_ID)).thenReturn(Optional.empty());

        assertThatCode(() -> service.annulerPaiementLie(ecriture("50000")))
                .doesNotThrowAnyException();
        verify(contraventionRepository, never()).save(any());
    }
}
