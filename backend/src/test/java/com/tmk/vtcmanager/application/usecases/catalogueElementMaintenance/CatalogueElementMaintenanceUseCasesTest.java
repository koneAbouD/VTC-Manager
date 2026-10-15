package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.vehicule.Marque;
import com.tmk.vtcmanager.application.domain.vehicule.Modele;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.MarqueRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
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
    private CreateCatalogueElementMaintenanceUseCase createUseCase;
    private GetActifsCatalogueElementsMaintenanceUseCase actifsUseCase;
    private MarqueRepository marqueRepository;
    private ModeleRepository modeleRepository;
    private VehiculeRepository vehiculeRepository;

    private static final Long TOYOTA = 1L;
    private static final Long HYUNDAI = 2L;
    private static final Long COROLLA = 10L;
    private static final Long YARIS = 11L;

    @BeforeEach
    void setUp() {
        repository = mock(CatalogueElementMaintenanceRepository.class);
        storage = mock(FileStoragePort.class);
        marqueRepository = mock(MarqueRepository.class);
        modeleRepository = mock(ModeleRepository.class);
        vehiculeRepository = mock(VehiculeRepository.class);
        CibleVehiculeCatalogue cible = new CibleVehiculeCatalogue(marqueRepository, modeleRepository);
        updateUseCase = new UpdateCatalogueElementMaintenanceUseCase(repository, storage, cible);
        toggleUseCase = new ToggleActifCatalogueElementMaintenanceUseCase(repository);
        createUseCase = new CreateCatalogueElementMaintenanceUseCase(repository, cible);
        actifsUseCase = new GetActifsCatalogueElementsMaintenanceUseCase(repository, vehiculeRepository);
        when(marqueRepository.existsById(TOYOTA)).thenReturn(true);
        when(modeleRepository.findById(COROLLA)).thenReturn(Optional.of(
                Modele.builder().id(COROLLA).nom("Corolla").marque(Marque.builder().id(TOYOTA).build()).build()));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    private CatalogueElementMaintenance element() {
        return CatalogueElementMaintenance.builder().id(7L).libelle("Vidange").actif(true).build();
    }

    @Test
    void update_modifie_le_libelle() {
        when(repository.findById(7L)).thenReturn(Optional.of(element()));

        CatalogueElementMaintenance maj = updateUseCase.execute(
                7L, "Vidange moteur", java.math.BigDecimal.valueOf(15000), "images/vidange.png", null, null);

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

        updateUseCase.execute(7L, "Vidange", null, "images/nouvelle.png", null, null);

        verify(storage).delete("images/ancienne.png");
    }

    @Test
    void update_conserve_l_image_si_inchangee() {
        CatalogueElementMaintenance existant = CatalogueElementMaintenance.builder()
                .id(7L).libelle("Vidange").actif(true).image("images/photo.png").build();
        when(repository.findById(7L)).thenReturn(Optional.of(existant));

        updateUseCase.execute(7L, "Vidange", null, "images/photo.png", null, null);

        verify(storage, never()).delete(any());
    }

    @Test
    void update_leve_not_found_si_absent() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> updateUseCase.execute(99L, "X", null, null, null, null))
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

    // ── Marque / modèle ─────────────────────────────────────────────────────

    @Test
    void create_deduit_la_marque_du_modele() {
        CatalogueElementMaintenance cree = createUseCase.execute(CatalogueElementMaintenance.builder()
                .libelle("Plaquettes").modeleId(COROLLA).build());

        assertThat(cree.getMarqueId()).isEqualTo(TOYOTA);
        assertThat(cree.getModeleId()).isEqualTo(COROLLA);
        assertThat(cree.isActif()).isTrue();
    }

    @Test
    void create_refuse_un_modele_d_une_autre_marque() {
        assertThatThrownBy(() -> createUseCase.execute(CatalogueElementMaintenance.builder()
                .libelle("Plaquettes").marqueId(HYUNDAI).modeleId(COROLLA).build()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("n'appartient pas");
        verify(repository, never()).save(any());
    }

    @Test
    void create_refuse_une_marque_inconnue() {
        assertThatThrownBy(() -> createUseCase.execute(CatalogueElementMaintenance.builder()
                .libelle("Plaquettes").marqueId(99L).build()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void update_rend_l_element_generique_sans_marque() {
        CatalogueElementMaintenance existant = CatalogueElementMaintenance.builder()
                .id(7L).libelle("Vidange").actif(true).marqueId(TOYOTA).modeleId(COROLLA).build();
        when(repository.findById(7L)).thenReturn(Optional.of(existant));

        CatalogueElementMaintenance maj = updateUseCase.execute(7L, "Vidange", null, null, null, null);

        assertThat(maj.getMarqueId()).isNull();
        assertThat(maj.getModeleId()).isNull();
    }

    @Test
    void actifs_filtre_selon_la_marque_et_le_modele_du_vehicule() {
        CatalogueElementMaintenance generique = CatalogueElementMaintenance.builder().id(1L).libelle("Lavage").build();
        CatalogueElementMaintenance toyota = CatalogueElementMaintenance.builder().id(2L).libelle("Filtre")
                .marqueId(TOYOTA).build();
        CatalogueElementMaintenance corolla = CatalogueElementMaintenance.builder().id(3L).libelle("Plaquettes")
                .marqueId(TOYOTA).modeleId(COROLLA).build();
        CatalogueElementMaintenance yaris = CatalogueElementMaintenance.builder().id(4L).libelle("Plaquettes")
                .marqueId(TOYOTA).modeleId(YARIS).build();
        CatalogueElementMaintenance hyundai = CatalogueElementMaintenance.builder().id(5L).libelle("Courroie")
                .marqueId(HYUNDAI).build();
        when(repository.findAllActifs()).thenReturn(List.of(generique, toyota, corolla, yaris, hyundai));
        when(vehiculeRepository.findById(42L)).thenReturn(Optional.of(Vehicule.builder().id(42L)
                .marque(Marque.builder().id(TOYOTA).build())
                .modele(Modele.builder().id(COROLLA).build()).build()));

        assertThat(actifsUseCase.execute(42L)).extracting(CatalogueElementMaintenance::getId)
                .containsExactly(1L, 2L, 3L);
        assertThat(actifsUseCase.execute((Long) null)).hasSize(5);
    }
}
