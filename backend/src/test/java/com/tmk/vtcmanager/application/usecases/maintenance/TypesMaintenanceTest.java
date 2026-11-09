package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Une intervention peut couvrir plusieurs types : le premier saisi est le type
 * principal, celui qui catégorise la dépense ; tous décident des éléments
 * proposés et de la reconnaissance d'une vidange.
 */
class TypesMaintenanceTest {

    private static final CategorieOperation VIDANGE = type(1L, "VIDANGE", "Vidange");
    private static final CategorieOperation FREINAGE = type(2L, "FREINAGE", "Freinage");

    private CategorieOperationRepository repository;

    @BeforeEach
    void setUp() {
        repository = mock(CategorieOperationRepository.class);
        when(repository.findBySousCategorieLibelle("Maintenances")).thenReturn(List.of(VIDANGE, FREINAGE));
    }

    @Test
    @DisplayName("Plusieurs types : le premier devient le type principal, sans doublon")
    void plusieurs_types() {
        Maintenance m = Maintenance.builder()
                .categoriesTypes(refs(2L, 1L, 2L))
                .build();

        TypesMaintenance.resoudre(m, repository);

        assertThat(m.getCategoriesTypes()).extracting(CategorieOperation::getCode)
                .containsExactly("FREINAGE", "VIDANGE");
        assertThat(m.getCategorieType().getId()).isEqualTo(2L);
        assertThat(m.getType()).isEqualTo("FREINAGE");
        assertThat(m.estVidange()).isTrue();
    }

    @Test
    @DisplayName("Client ancien : le seul code du type suffit")
    void code_seul() {
        Maintenance m = Maintenance.builder().type("VIDANGE").build();

        TypesMaintenance.resoudre(m, repository);

        assertThat(m.getCategoriesTypes()).containsExactly(VIDANGE);
        assertThat(m.getCategorieType()).isEqualTo(VIDANGE);
    }

    @Test
    @DisplayName("Type principal seul : il devient l'unique type")
    void principal_seul() {
        Maintenance m = Maintenance.builder()
                .categorieType(CategorieOperation.builder().id(1L).build())
                .build();

        TypesMaintenance.resoudre(m, repository);

        assertThat(m.getCategoriesTypes()).containsExactly(VIDANGE);
        assertThat(m.getType()).isEqualTo("VIDANGE");
    }

    @Test
    @DisplayName("Un type hors des maintenances est refusé")
    void type_inconnu() {
        Maintenance m = Maintenance.builder().categoriesTypes(refs(1L, 99L)).build();

        assertThatThrownBy(() -> TypesMaintenance.resoudre(m, repository))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private static List<CategorieOperation> refs(Long... ids) {
        List<CategorieOperation> refs = new ArrayList<>();
        for (Long id : ids) refs.add(CategorieOperation.builder().id(id).build());
        return refs;
    }

    private static CategorieOperation type(Long id, String code, String libelle) {
        return CategorieOperation.builder().id(id).code(code).libelle(libelle).build();
    }
}
