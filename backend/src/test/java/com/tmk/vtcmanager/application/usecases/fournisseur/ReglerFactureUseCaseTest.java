package com.tmk.vtcmanager.application.usecases.fournisseur;

import com.tmk.vtcmanager.application.domain.fournisseur.FactureFournisseur;
import com.tmk.vtcmanager.application.domain.fournisseur.Fournisseur;
import com.tmk.vtcmanager.application.domain.fournisseur.StatutFactureFournisseur;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.ports.persistence.FactureFournisseurRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.CaisseClotureeGuard;
import com.tmk.vtcmanager.application.services.CompteTresorerieResolver;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.services.SequenceReferenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Le règlement sort l'argent et réduit la dette ; la charge, elle, a déjà été
 * constatée à la réception de la facture.
 */
class ReglerFactureUseCaseTest {

    private static final Long COMPTE = 1L;
    private static final LocalDate LE_10_MARS = LocalDate.of(2026, 3, 10);

    private FactureFournisseurRepository factureRepository;
    private OperationFinanciereRepository operationRepository;
    private CompteTresorerieResolver compteTresorerieResolver;
    private PeriodeClotureeGuard periodeClotureeGuard;
    private CaisseClotureeGuard caisseClotureeGuard;
    private SequenceReferenceService sequenceReferenceService;
    private ReglerFactureUseCase useCase;

    @BeforeEach
    void setUp() {
        factureRepository = mock(FactureFournisseurRepository.class);
        operationRepository = mock(OperationFinanciereRepository.class);
        compteTresorerieResolver = mock(CompteTresorerieResolver.class);
        periodeClotureeGuard = mock(PeriodeClotureeGuard.class);
        caisseClotureeGuard = mock(CaisseClotureeGuard.class);
        sequenceReferenceService = mock(SequenceReferenceService.class);

        when(compteTresorerieResolver.resoudre(any(), any())).thenReturn(COMPTE);
        when(sequenceReferenceService.suivante(any(), any())).thenReturn("RGF-2026-000001");
        when(operationRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(factureRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        useCase = new ReglerFactureUseCase(factureRepository, operationRepository,
                compteTresorerieResolver, periodeClotureeGuard, caisseClotureeGuard,
                sequenceReferenceService);
    }

    private FactureFournisseur facture(String montant, String paye, StatutFactureFournisseur statut) {
        FactureFournisseur f = FactureFournisseur.builder()
                .id(50L)
                .reference("FRN-2026-000001")
                .fournisseur(Fournisseur.builder().id(3L).nom("Garage Cocody").build())
                .categorie(CategorieOperation.builder().id(9L).libelle("Maintenance").build())
                .dateFacture(LE_10_MARS)
                .dateEcheance(LE_10_MARS.plusDays(30))
                .montant(new BigDecimal(montant))
                .montantPaye(new BigDecimal(paye))
                .statut(statut)
                .build();
        when(factureRepository.findById(50L)).thenReturn(Optional.of(f));
        return f;
    }

    @Test
    @DisplayName("Un règlement partiel réduit la dette et passe la facture en partiellement payée")
    void reglement_partiel() {
        facture("120000", "0", StatutFactureFournisseur.A_PAYER);

        FactureFournisseur apres = useCase.executer(50L, new BigDecimal("50000"),
                ModePaiement.ESPECES, null, LocalDate.of(2026, 3, 20), null);

        assertThat(apres.getMontantPaye()).isEqualByComparingTo("50000");
        assertThat(apres.restantDu()).isEqualByComparingTo("70000");
        assertThat(apres.getStatut()).isEqualTo(StatutFactureFournisseur.PARTIELLEMENT_PAYEE);
    }

    @Test
    @DisplayName("Le solde du restant dû clôt la facture")
    void reglement_solde() {
        facture("120000", "70000", StatutFactureFournisseur.PARTIELLEMENT_PAYEE);

        FactureFournisseur apres = useCase.executer(50L, new BigDecimal("50000"),
                ModePaiement.ESPECES, null, null, null);

        assertThat(apres.restantDu()).isEqualByComparingTo("0");
        assertThat(apres.getStatut()).isEqualTo(StatutFactureFournisseur.PAYEE);
    }

    @Test
    @DisplayName("L'écriture générée est une sortie de caisse liée à la facture")
    void ecriture_de_reglement() {
        facture("120000", "0", StatutFactureFournisseur.A_PAYER);

        useCase.executer(50L, new BigDecimal("120000"), ModePaiement.MOBILE_MONEY, 2L,
                LocalDate.of(2026, 3, 20), null);

        ArgumentCaptor<OperationFinanciere> capture =
                ArgumentCaptor.forClass(OperationFinanciere.class);
        verify(operationRepository).save(capture.capture());
        OperationFinanciere op = capture.getValue();

        assertThat(op.getTypeOperation()).isEqualTo(TypeOperation.DEPENSE);
        assertThat(op.getStatut()).isEqualTo(StatutOperation.PAYE);
        assertThat(op.getMontant()).isEqualByComparingTo("120000");
        assertThat(op.getDateOperation()).isEqualTo(LocalDate.of(2026, 3, 20));
        // Date métier = celle de la facture : le règlement se rattache à la charge.
        assertThat(op.getDateReference()).isEqualTo(LE_10_MARS);
        // Le lien qui évite de compter la charge deux fois en base engagement.
        assertThat(op.getFactureFournisseurId()).isEqualTo(50L);
        assertThat(op.getCommentaire()).contains("Garage Cocody");
    }

    @Test
    @DisplayName("On ne règle pas plus que le restant dû")
    void reglement_excessif_refuse() {
        facture("120000", "100000", StatutFactureFournisseur.PARTIELLEMENT_PAYEE);

        assertThatThrownBy(() -> useCase.executer(50L, new BigDecimal("30000"),
                ModePaiement.ESPECES, null, null, null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("dépasse le restant dû");
        verify(operationRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une facture déjà soldée ne se règle plus")
    void facture_soldee_refuse() {
        facture("120000", "120000", StatutFactureFournisseur.PAYEE);

        assertThatThrownBy(() -> useCase.executer(50L, new BigDecimal("1000"),
                ModePaiement.ESPECES, null, null, null))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("Une facture annulée ne se règle pas")
    void facture_annulee_refuse() {
        facture("120000", "0", StatutFactureFournisseur.ANNULEE);

        assertThatThrownBy(() -> useCase.executer(50L, new BigDecimal("1000"),
                ModePaiement.ESPECES, null, null, null))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("Le règlement respecte les verrous de période et de caisse")
    void verrous_appliques() {
        facture("120000", "0", StatutFactureFournisseur.A_PAYER);

        useCase.executer(50L, new BigDecimal("10000"), ModePaiement.ESPECES, null,
                LocalDate.of(2026, 3, 20), null);

        verify(periodeClotureeGuard).verifier(LocalDate.of(2026, 3, 20));
        verify(caisseClotureeGuard).verifier(COMPTE, LocalDate.of(2026, 3, 20));
    }

    @Test
    @DisplayName("Un montant nul ou négatif est refusé")
    void montant_invalide() {
        facture("120000", "0", StatutFactureFournisseur.A_PAYER);

        assertThatThrownBy(() -> useCase.executer(50L, BigDecimal.ZERO,
                ModePaiement.ESPECES, null, null, null))
                .isInstanceOf(IllegalArgumentException.class);
        verify(factureRepository, never()).save(any());
        verify(operationRepository, never()).save(any());
        verify(caisseClotureeGuard, never()).verifier(anyLong(), any());
    }
}
