package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
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
    private FileStoragePort storage;
    private UpdateCatalogueElementMaintenanceUseCase updateUseCase;
    private ToggleActifCatalogueElementMaintenanceUseCase toggleUseCase;

    @BeforeEach
    void setUp() {
        repository = mock(CatalogueElementMaintenanceRepository.class);
        storage = mock(FileStoragePort.class);
        updateUseCase = new UpdateCatalogueElementMaintenanceUseCase(repository, storage);
        toggleUseCase = new ToggleActifCatalogueElementMaintenanceUseCase(repository);
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    private CatalogueElementMaintenance element() {
        return CatalogueElementMaintenance.builder().id(7L).libelle("Vidange").actif(true).build();
    }

    @Test
    void update_modifie_le_libelle() {
        when(repository.findById(7L)).thenReturn(Optional.of(element()));

        CatalogueElementMaintenance maj = updateUseCase.execute(
                7L, "Vidange moteur", java.math.BigDecimal.valueOf(15000), "images/vidange.png");

        assertThat(maj.getLibelle()).isEqualTo("Vidange moteur");
        assertThat(maj.getMontantDefaut()).isEqualByComparingTo("15000");
        assertThat(maj.getImage()).isEqualTo("images/vidange.png");
        verify(repository).save(any(CatalogueElementMaintenance.class));
    }

    @Test
    void update_supprime_l_ancienne_image_si_remplacee() {
        CatalogueElementMaintenance existant = CatalogueElementMaintenance.builder()
                .id(7L).libelle("Vidange").actif(true).image("images/ancienne.png").build();
        when(repository.findById(7L)).thenReturn(Optional.of(existant));

        updateUseCase.execute(7L, "Vidange", null, "images/nouvelle.png");

        verify(storage).delete("images/ancienne.png");
    }

    @Test
    void update_conserve_l_image_si_inchangee() {
        CatalogueElementMaintenance existant = CatalogueElementMaintenance.builder()
                .id(7L).libelle("Vidange").actif(true).image("images/photo.png").build();
        when(repository.findById(7L)).thenReturn(Optional.of(existant));

        updateUseCase.execute(7L, "Vidange", null, "images/photo.png");

        verify(storage, never()).delete(any());
    }

    @Test
    void update_leve_not_found_si_absent() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> updateUseCase.execute(99L, "X", null, null))
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
