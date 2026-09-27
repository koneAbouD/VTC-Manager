package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.EncaissementFuturGuard;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PayContraventionUseCaseTest {

    private static final Long ID = 7L;
    private static final Long CAISSE = 3L;

    private ContraventionRepository contraventionRepository;
    private OperationFinanciereRepository operationFinanciereRepository;
    private CaisseClotureeGuard caisseClotureeGuard;
    private EncaissementFuturGuard encaissementFuturGuard;
    private PayContraventionUseCase useCase;

    @BeforeEach
    void setUp() {
        contraventionRepository = mock(ContraventionRepository.class);
        operationFinanciereRepository = mock(OperationFinanciereRepository.class);
        CategorieOperationRepository categorieOperationRepository = mock(CategorieOperationRepository.class);
        CompteTresorerieResolver resolver = mock(CompteTresorerieResolver.class);
        SequenceReferenceService sequence = mock(SequenceReferenceService.class);
        caisseClotureeGuard = mock(CaisseClotureeGuard.class);
        encaissementFuturGuard = mock(EncaissementFuturGuard.class);

        when(categorieOperationRepository.findByCode(any())).thenReturn(Optional.empty());
        when(resolver.resoudre(null, ModePaiement.MOBILE_MONEY)).thenReturn(CAISSE);
        when(sequence.suivante(any(), any())).thenReturn("CTV-2026-000001");
        when(contraventionRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        useCase = new PayContraventionUseCase(contraventionRepository, operationFinanciereRepository,
                categorieOperationRepository, resolver, sequence, caisseClotureeGuard,
                mock(PeriodeClotureeGuard.class), encaissementFuturGuard);
    }

    private Contravention reversee(int paye) {
        Contravention c = Contravention.builder()
                .id(ID).typeInfraction("Excès de vitesse")
                .dateInfraction(LocalDate.of(2026, 8, 2))
                .montant(BigDecimal.valueOf(10_000))
                .montantPaye(BigDecimal.valueOf(paye))
                .statut(ContraventionStatus.REVERSE)
                .build();
        when(contraventionRepository.findById(ID)).thenReturn(Optional.of(c));
        return c;
    }

    @Test
    @DisplayName("Le remboursement d'une reversée entre en caisse à la date saisie, statut conservé")
    void remboursement_reversee() {
        reversee(0);
        LocalDate jour = LocalDate.of(2026, 9, 20);

        Contravention c = useCase.execute(ID, BigDecimal.valueOf(10_000), ModePaiement.MOBILE_MONEY,
                jour, "TX-42", null);

        assertThat(c.getStatut()).isEqualTo(ContraventionStatus.REVERSE);
        assertThat(c.getMontantPaye()).isEqualByComparingTo("10000");
        assertThat(c.getDatePaiement()).isEqualTo(jour);

        ArgumentCaptor<OperationFinanciere> op = ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationFinanciereRepository).save(op.capture());
        assertThat(op.getValue().getCompteTresorerieId()).isEqualTo(CAISSE);
        assertThat(op.getValue().getDateOperation()).isEqualTo(jour);
        assertThat(op.getValue().getContraventionId()).isEqualTo(ID);
        assertThat(op.getValue().getCommentaire()).contains("TX-42");
        verify(caisseClotureeGuard).verifier(CAISSE, jour);
    }

    @Test
    @DisplayName("On n'encaisse pas plus que le reste dû")
    void depassement_refuse() {
        reversee(4_000);

        assertThatThrownBy(() -> useCase.execute(ID, BigDecimal.valueOf(7_000),
                ModePaiement.MOBILE_MONEY, null, null, null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("6000");
        verify(operationFinanciereRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une contravention annulée ne s'encaisse plus")
    void annulee_refusee() {
        Contravention c = reversee(0);
        c.setAnnuleLe(LocalDateTime.now());

        assertThatThrownBy(() -> useCase.execute(ID, BigDecimal.valueOf(1_000),
                ModePaiement.MOBILE_MONEY, null, null, null))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("Un encaissement postdaté est refusé avant toute écriture")
    void postdate_refuse() {
        reversee(0);
        LocalDate demain = LocalDate.now().plusDays(1);
        doThrow(new IllegalArgumentException("futur")).when(encaissementFuturGuard).verifier(demain);

        assertThatThrownBy(() -> useCase.execute(ID, BigDecimal.valueOf(1_000),
                ModePaiement.MOBILE_MONEY, demain, null, null))
                .isInstanceOf(IllegalArgumentException.class);
        verify(contraventionRepository, never()).save(any());
    }
}
