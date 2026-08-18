package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.ModificationEcritureGuard;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Deux familles d'écritures ne se retouchent pas en place : les encaissements
 * et les dépenses issues d'une maintenance.
 *
 * <p>Leur montant n'est pas une donnée de l'écriture mais le reflet d'un fait
 * enregistré ailleurs — un versement porté par une créance, un coût validé à la
 * complétion d'une intervention. Le corriger ici laisserait la source intacte
 * et les deux se contrediraient en silence. La voie est l'annulation, qui
 * repositionne la source, puis la ressaisie.
 */
class UpdateOperationFinanciereUseCaseTest {

    private static final LocalDate JOUR = LocalDate.of(2026, 4, 10);

    private OperationFinanciereRepository operationRepository;
    private ModificationEcritureGuard modificationEcritureGuard;
    private UpdateOperationFinanciereUseCase useCase;

    @BeforeEach
    void setUp() {
        operationRepository = mock(OperationFinanciereRepository.class);
        modificationEcritureGuard = mock(ModificationEcritureGuard.class);
        when(operationRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        useCase = new UpdateOperationFinanciereUseCase(operationRepository, modificationEcritureGuard);
    }

    private void existante(OperationFinanciere operation) {
        when(operationRepository.findById(1L)).thenReturn(Optional.of(operation));
    }

    private OperationFinanciere.OperationFinanciereBuilder ecriture() {
        return OperationFinanciere.builder()
                .id(1L)
                .typeOperation(TypeOperation.DEPENSE)
                .montant(BigDecimal.valueOf(75_000))
                .dateOperation(JOUR)
                .statut(StatutOperation.PAYE);
    }

    private OperationFinanciere modification() {
        return ecriture().montant(BigDecimal.valueOf(90_000)).build();
    }

    private CategorieOperation categorie(String code) {
        return CategorieOperation.builder().id(3L).code(code).build();
    }

    @Test
    @DisplayName("Un encaissement de recette ne se modifie pas")
    void encaissement_recette_fige() {
        existante(ecriture().typeOperation(TypeOperation.REVENU)
                .statut(StatutOperation.ENCAISSE)
                .categorie(categorie("ENCAISSEMENT_RECETTES")).build());

        assertThatThrownBy(() -> useCase.execute(1L, modification()))
                .isInstanceOf(EcritureFigeeException.class)
                .hasMessageContaining("encaissement");

        verify(operationRepository, never()).save(any());
    }

    @Test
    @DisplayName("Un remboursement de contravention ne se modifie pas davantage")
    void encaissement_contravention_fige() {
        existante(ecriture().typeOperation(TypeOperation.REVENU)
                .statut(StatutOperation.ENCAISSE)
                .categorie(categorie("CONTRAVENTION_REMBOURSEMENT")).build());

        assertThatThrownBy(() -> useCase.execute(1L, modification()))
                .isInstanceOf(EcritureFigeeException.class);
    }

    @Test
    @DisplayName("Une dépense issue d'une maintenance ne se modifie pas")
    void depense_de_maintenance_figee() {
        existante(ecriture().maintenanceId(300L).categorie(categorie("REPARATION")).build());

        assertThatThrownBy(() -> useCase.execute(1L, modification()))
                .isInstanceOf(EcritureFigeeException.class)
                .hasMessageContaining("maintenance");

        verify(operationRepository, never()).save(any());
    }

    @Test
    @DisplayName("Une dépense saisie à la main reste modifiable")
    void depense_manuelle_modifiable() {
        existante(ecriture().categorie(categorie("REPARATION")).build());

        OperationFinanciere sauvee = useCase.execute(1L, modification());

        assertThat(sauvee.getMontant()).isEqualByComparingTo("90000");
        verify(operationRepository).save(any());
    }

    @Test
    @DisplayName("Une opération annulée ne se modifie pas")
    void operation_annulee() {
        existante(ecriture().statut(StatutOperation.ANNULEE).build());

        assertThatThrownBy(() -> useCase.execute(1L, modification()))
                .isInstanceOf(IllegalStateException.class);
    }
}
