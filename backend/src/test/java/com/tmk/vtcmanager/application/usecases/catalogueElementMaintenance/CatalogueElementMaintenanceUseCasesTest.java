package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class CatalogueElementMaintenanceUseCasesTest {

    private CatalogueElementMaintenanceRepository repository;
    private UpdateCatalogueElementMaintenanceUseCase updateUseCase;
    private ToggleActifCatalogueElementMaintenanceUseCase toggleUseCase;

    @BeforeEach
    void setUp() {
        repository = mock(CatalogueElementMaintenanceRepository.class);
        updateUseCase = new UpdateCatalogueElementMaintenanceUseCase(repository);
        toggleUseCase = new ToggleActifCatalogueElementMaintenanceUseCase(repository);
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    private CatalogueElementMaintenance element() {
        return CatalogueElementMaintenance.builder().id(7L).libelle("Vidange").actif(true).build();
    }

    @Test
    void update_modifie_le_libelle() {
        when(repository.findById(7L)).thenReturn(Optional.of(element()));

        CatalogueElementMaintenance maj = updateUseCase.execute(7L, "Vidange moteur");

        assertThat(maj.getLibelle()).isEqualTo("Vidange moteur");
        verify(repository).save(any(CatalogueElementMaintenance.class));
    }

    @Test
    void update_leve_not_found_si_absent() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> updateUseCase.execute(99L, "X"))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void toggle_desactive_l_element() {
        when(repository.findById(7L)).thenReturn(Optional.of(element()));

        CatalogueElementMaintenance maj = toggleUseCase.execute(7L, false);

        assertThat(maj.isActif()).isFalse();
        verify(repository).save(any(CatalogueElementMaintenance.class));
    }

    @Test
    void toggle_leve_not_found_si_absent() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> toggleUseCase.execute(99L, true))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).save(any());
    }
}
