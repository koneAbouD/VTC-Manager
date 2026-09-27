package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.NatureResultat;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.StatutOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Export du journal pour le cabinet : une compensation d'arrêté n'est pas un
 * encaissement, elle sort en opération diverse équilibrée (dépôt ↔ produit).
 */
@DisplayName("Export comptable")
class ExportComptableUseCaseTest {

    private static final LocalDate JOUR = LocalDate.of(2026, 9, 30);

    private OperationFinanciereRepository operations;
    private ExportComptableUseCase useCase;

    private final CategorieOperation depot = CategorieOperation.builder()
            .code("ENCAISSEMENT_COTISATIONS").libelle("Encaissement cotisations")
            .typeOperation(TypeOperation.REVENU).natureResultat(NatureResultat.HORS_RESULTAT)
            .compteComptable("4191").build();
    private final CategorieOperation recette = CategorieOperation.builder()
            .code("ENCAISSEMENT_RECETTES").libelle("Encaissement recettes")
            .typeOperation(TypeOperation.REVENU).natureResultat(NatureResultat.PRODUIT_EXPLOITATION)
            .compteComptable("706").build();

    @BeforeEach
    void setUp() {
        operations = mock(OperationFinanciereRepository.class);
        CategorieOperationRepository categories = mock(CategorieOperationRepository.class);
        when(categories.findByCode("ENCAISSEMENT_COTISATIONS")).thenReturn(Optional.of(depot));
        useCase = new ExportComptableUseCase(operations, categories);
    }

    private OperationFinanciere operation(String reference, Long compteId, CategorieOperation categorie) {
        return OperationFinanciere.builder()
                .reference(reference).typeOperation(TypeOperation.REVENU).categorie(categorie)
                .montant(BigDecimal.valueOf(30)).modePaiement(ModePaiement.ESPECES)
                .compteTresorerieId(compteId).dateOperation(JOUR)
                .statut(StatutOperation.ENCAISSE).commentaire("Compensation cotisation ARR-2026-1")
                .build();
    }

    private List<String> lignes() {
        return List.of(useCase.executer(2026, 9).split("\n"));
    }

    @Test
    @DisplayName("une compensation sort en deux lignes équilibrées, sans mode espèces")
    void compensationEnOperationDiverse() {
        when(operations.findByCriteres(any())).thenReturn(List.of(
                operation("COMP-2026-000001", null, recette)));

        List<String> lignes = lignes();

        assertThat(lignes).hasSize(3);
        assertThat(lignes.get(1)).isEqualTo("2026-09-30;COMP-2026-000001;Dépôts cotisations chauffeurs;"
                + "4191;HORS_RESULTAT;30;;;;COMPENSATION;Compensation cotisation ARR-2026-1");
        assertThat(lignes.get(2)).isEqualTo("2026-09-30;COMP-2026-000001;Encaissement recettes;"
                + "706;PRODUIT_EXPLOITATION;;30;;;COMPENSATION;Compensation cotisation ARR-2026-1");
    }

    @Test
    @DisplayName("un encaissement réel reste une seule ligne avec son mode")
    void encaissementOrdinaire() {
        when(operations.findByCriteres(any())).thenReturn(List.of(
                operation("REC-2026-000001", 9L, recette)));

        List<String> lignes = lignes();

        assertThat(lignes).hasSize(2);
        assertThat(lignes.get(1)).contains(";706;PRODUIT_EXPLOITATION;;30;").contains(";ESPECES;");
    }

    @Test
    @DisplayName("une écriture annulée n'est pas exportée")
    void compensationAnnulee() {
        OperationFinanciere annulee = operation("COMP-2026-000002", null, recette);
        annulee.setStatut(StatutOperation.ANNULEE);
        when(operations.findByCriteres(any())).thenReturn(List.of(annulee));

        assertThat(lignes()).hasSize(1);
    }
}
