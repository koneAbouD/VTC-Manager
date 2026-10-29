package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.ElementCatalogue;
import com.tmk.vtcmanager.application.domain.operation.PropositionCatalogue;
import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.domain.vehicule.Marque;
import com.tmk.vtcmanager.application.domain.vehicule.Modele;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import com.tmk.vtcmanager.application.ports.persistence.TarifElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Catalogue des éléments de maintenance : un élément porte ce qui vaut pour
 * tous les modèles (libellé, type), ses tarifs ce qui dépend du modèle (prix,
 * image, activation). La saisie d'une maintenance ne propose un élément que
 * pour les modèles où il a un tarif actif, au prix de ce modèle.
 */
class CatalogueElementMaintenanceUseCasesTest {

    private static final Long S_PRESSO = 51L;
    private static final Long DZIRE = 52L;
    private static final Long VIDANGE = 13L;
    private static final Long FREINAGE = 16L;
    private static final Long RECETTE = 1L;

    private CatalogueElementMaintenanceRepository repository;
    private TarifElementMaintenanceRepository tarifRepository;
    private ModeleRepository modeleRepository;
    private VehiculeRepository vehiculeRepository;
    private CategorieOperationRepository categorieRepository;
    private FileStoragePort storage;

    private UpdateCatalogueElementMaintenanceUseCase updateUseCase;
    private ToggleActifCatalogueElementMaintenanceUseCase toggleUseCase;
    private CreateCatalogueElementMaintenanceUseCase createUseCase;
    private GetActifsCatalogueElementsMaintenanceUseCase actifsUseCase;
    private GetAllCatalogueElementsMaintenanceUseCase tousUseCase;
    private EnregistrerTarifElementMaintenanceUseCase enregistrerTarif;
    private SupprimerTarifElementMaintenanceUseCase supprimerTarif;
    private CopierTarifsElementsMaintenanceUseCase copierTarifs;
    private DeleteCatalogueElementMaintenanceUseCase deleteUseCase;

    @BeforeEach
    void setUp() {
        repository = mock(CatalogueElementMaintenanceRepository.class);
        tarifRepository = mock(TarifElementMaintenanceRepository.class);
        modeleRepository = mock(ModeleRepository.class);
        vehiculeRepository = mock(VehiculeRepository.class);
        categorieRepository = mock(CategorieOperationRepository.class);
        storage = mock(FileStoragePort.class);

        TypeMaintenanceCatalogue type = new TypeMaintenanceCatalogue(categorieRepository);
        ImagesCatalogueMaintenance images = new ImagesCatalogueMaintenance(tarifRepository, storage);
        enregistrerTarif = new EnregistrerTarifElementMaintenanceUseCase(
                repository, tarifRepository, modeleRepository, images);
        updateUseCase = new UpdateCatalogueElementMaintenanceUseCase(repository, type);
        toggleUseCase = new ToggleActifCatalogueElementMaintenanceUseCase(repository);
        createUseCase = new CreateCatalogueElementMaintenanceUseCase(repository, type, enregistrerTarif);
        actifsUseCase = new GetActifsCatalogueElementsMaintenanceUseCase(
                repository, tarifRepository, vehiculeRepository);
        tousUseCase = new GetAllCatalogueElementsMaintenanceUseCase(repository, tarifRepository);
        supprimerTarif = new SupprimerTarifElementMaintenanceUseCase(tarifRepository, images);
        copierTarifs = new CopierTarifsElementsMaintenanceUseCase(tarifRepository, modeleRepository);
        deleteUseCase = new DeleteCatalogueElementMaintenanceUseCase(repository, tarifRepository, images);

        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(tarifRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(categorieRepository.findBySousCategorieLibelle("Maintenances")).thenReturn(List.of(
                CategorieOperation.builder().id(VIDANGE).code("VIDANGE").libelle("Vidange").build(),
                CategorieOperation.builder().id(FREINAGE).code("FREINAGE").libelle("Freinage").build()));
        for (Long modele : List.of(S_PRESSO, DZIRE)) {
            when(modeleRepository.findById(modele)).thenReturn(Optional.of(
                    Modele.builder().id(modele).marque(Marque.builder().id(1L).build()).build()));
        }
    }

    private static CatalogueElementMaintenance element(Long id, String libelle) {
        return CatalogueElementMaintenance.builder().id(id).libelle(libelle).actif(true).build();
    }

    private static TarifElementMaintenance tarif(Long id, Long elementId, Long modeleId,
                                                 Integer prix, String image, boolean actif) {
        return TarifElementMaintenance.builder().id(id).elementId(elementId).modeleId(modeleId)
                .prix(prix == null ? null : BigDecimal.valueOf(prix)).image(image).actif(actif).build();
    }

    private void vehicule(Long id, Long modeleId) {
        when(vehiculeRepository.findById(id)).thenReturn(Optional.of(Vehicule.builder().id(id)
                .modele(modeleId == null ? null : Modele.builder().id(modeleId).build()).build()));
    }

    @Nested
    @DisplayName("Élément : ce qui vaut pour tous les modèles")
    class Element {

        @Test
        @DisplayName("la mise à jour change le libellé et le type, rien d'autre")
        void update_modifie_libelle_et_type() {
            when(repository.findById(7L)).thenReturn(Optional.of(element(7L, "Vidange")));

            CatalogueElementMaintenance maj = updateUseCase.execute(7L, "Filtre à huile", VIDANGE);

            assertThat(maj.getLibelle()).isEqualTo("Filtre à huile");
            assertThat(maj.getCategorieTypeLibelle()).isEqualTo("Vidange");
            verify(tarifRepository, never()).save(any());
        }

        @Test
        @DisplayName("sans type, l'élément redevient commun à toutes les maintenances")
        void update_rend_l_element_commun_sans_type() {
            CatalogueElementMaintenance existant = element(7L, "Main d'oeuvre");
            existant.affecterType(FREINAGE, "Freinage");
            when(repository.findById(7L)).thenReturn(Optional.of(existant));

            CatalogueElementMaintenance maj = updateUseCase.execute(7L, "Main d'oeuvre", null);

            assertThat(maj.getCategorieTypeId()).isNull();
        }

        @Test
        @DisplayName("un élément absent est signalé")
        void update_leve_not_found_si_absent() {
            when(repository.findById(99L)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> updateUseCase.execute(99L, "X", null))
                    .isInstanceOf(ResourceNotFoundException.class);
            verify(repository, never()).save(any());
        }

        @Test
        @DisplayName("désactiver l'élément le retire de tous les modèles")
        void toggle_desactive_l_element() {
            when(repository.findById(7L)).thenReturn(Optional.of(element(7L, "Vidange")));

            assertThat(toggleUseCase.execute(7L, false).isActif()).isFalse();
        }

        @Test
        @DisplayName("une catégorie qui n'est pas un type de maintenance est refusée")
        void create_refuse_une_categorie_hors_maintenance() {
            assertThatThrownBy(() -> createUseCase.execute(CatalogueElementMaintenance.builder()
                    .libelle("Filtre à huile").categorieTypeId(RECETTE).build(), null, null, null))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("type de maintenance");
            verify(repository, never()).save(any());
        }

        @Test
        @DisplayName("créé depuis l'onglet d'un modèle, l'élément y reçoit aussitôt son prix et son image")
        void create_avec_modele_cree_le_tarif() {
            when(repository.save(any())).thenAnswer(inv -> {
                CatalogueElementMaintenance e = inv.getArgument(0);
                e.setId(40L);
                return e;
            });
            when(repository.findById(40L)).thenReturn(Optional.of(element(40L, "Filtre à huile")));
            when(tarifRepository.findByElementIdAndModeleId(40L, S_PRESSO)).thenReturn(Optional.empty());

            ElementCatalogue cree = createUseCase.execute(CatalogueElementMaintenance.builder()
                            .libelle("Filtre à huile").categorieTypeId(VIDANGE).build(),
                    S_PRESSO, BigDecimal.valueOf(2000), "img/filtre.png");

            assertThat(cree.element().isActif()).isTrue();
            assertThat(cree.tarifPour(S_PRESSO)).get()
                    .satisfies(t -> {
                        assertThat(t.getPrix()).isEqualByComparingTo("2000");
                        assertThat(t.getImage()).isEqualTo("img/filtre.png");
                        assertThat(t.isActif()).isTrue();
                    });
        }

        @Test
        @DisplayName("créé sans modèle, l'élément n'est encore proposé nulle part")
        void create_sans_modele_ne_cree_pas_de_tarif() {
            ElementCatalogue cree = createUseCase.execute(
                    CatalogueElementMaintenance.builder().libelle("Filtre").build(), null, null, null);

            assertThat(cree.tarifs()).isEmpty();
            verify(tarifRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("Proposition à la saisie d'une maintenance")
    class Proposition {

        private final CatalogueElementMaintenance filtre = element(1L, "Filtre à huile");
        private final CatalogueElementMaintenance plaquette = element(2L, "Plaquette");
        private final CatalogueElementMaintenance mainOeuvre = element(3L, "Main d'oeuvre");

        @BeforeEach
        void catalogue() {
            filtre.affecterType(VIDANGE, "Vidange");
            plaquette.affecterType(FREINAGE, "Freinage");
            when(repository.findAllActifs()).thenReturn(List.of(filtre, plaquette, mainOeuvre));
            when(tarifRepository.findByModeleId(S_PRESSO)).thenReturn(List.of(
                    tarif(10L, 1L, S_PRESSO, 2000, "img/filtre-spresso.png", true),
                    tarif(11L, 2L, S_PRESSO, 5500, null, false),
                    tarif(12L, 3L, S_PRESSO, null, null, true)));
        }

        @Test
        @DisplayName("seuls les éléments au tarif actif pour le modèle du véhicule, au prix de ce modèle")
        void propose_selon_le_modele_du_vehicule() {
            vehicule(42L, S_PRESSO);

            PropositionCatalogue p = actifsUseCase.execute(42L, null);

            assertThat(p.modeleId()).isEqualTo(S_PRESSO);
            // La plaquette a un tarif S-Presso, mais désactivé : pas proposée.
            assertThat(p.elements()).extracting(ec -> ec.element().getId()).containsExactly(1L, 3L);
            assertThat(p.elements().get(0).tarifPour(S_PRESSO).orElseThrow().getPrix())
                    .isEqualByComparingTo("2000");
        }

        @Test
        @DisplayName("le type de maintenance restreint aux éléments communs et de ce type")
        void combine_modele_et_type() {
            vehicule(42L, S_PRESSO);

            assertThat(actifsUseCase.execute(42L, VIDANGE).elements())
                    .extracting(ec -> ec.element().getId())
                    .containsExactly(1L, 3L);
            assertThat(actifsUseCase.execute(42L, FREINAGE).elements())
                    .extracting(ec -> ec.element().getId())
                    .containsExactly(3L);
        }

        @Test
        @DisplayName("un modèle sans tarif ne se voit rien proposer")
        void modele_sans_tarif() {
            vehicule(43L, DZIRE);
            when(tarifRepository.findByModeleId(DZIRE)).thenReturn(List.of());

            assertThat(actifsUseCase.execute(43L, null).elements()).isEmpty();
        }

        @Test
        @DisplayName("un véhicule sans modèle ne se voit rien proposer")
        void vehicule_sans_modele() {
            vehicule(44L, null);

            PropositionCatalogue p = actifsUseCase.execute(44L, null);

            assertThat(p.modeleId()).isNull();
            assertThat(p.elements()).isEmpty();
        }

        @Test
        @DisplayName("sans véhicule, tous les éléments actifs, sans prix ni image")
        void sans_vehicule() {
            PropositionCatalogue p = actifsUseCase.execute(null, null);

            assertThat(p.modeleId()).isNull();
            assertThat(p.elements()).hasSize(3).allSatisfy(ec -> assertThat(ec.tarifs()).isEmpty());
        }

        @Test
        @DisplayName("l'onglet d'un modèle montre ses éléments, tarifs inactifs compris")
        void parametrage_par_modele() {
            when(repository.findAll()).thenReturn(List.of(filtre, plaquette, mainOeuvre));
            when(tarifRepository.findAll()).thenReturn(List.of(
                    tarif(10L, 1L, S_PRESSO, 2000, null, true),
                    tarif(11L, 2L, S_PRESSO, 5500, null, false),
                    tarif(20L, 1L, DZIRE, 2200, null, true)));

            assertThat(tousUseCase.execute(S_PRESSO)).extracting(ec -> ec.element().getId())
                    .containsExactly(1L, 2L);
            assertThat(tousUseCase.execute(DZIRE)).extracting(ec -> ec.element().getId())
                    .containsExactly(1L);
            // Sans modèle : tout le catalogue, avec les tarifs de chaque modèle.
            assertThat(tousUseCase.execute((Long) null)).hasSize(3)
                    .first().satisfies(ec -> assertThat(ec.tarifs()).hasSize(2));
        }
    }

    @Nested
    @DisplayName("Tarif : prix, image et activation par modèle")
    class Tarif {

        @BeforeEach
        void elementExiste() {
            when(repository.findById(1L)).thenReturn(Optional.of(element(1L, "Filtre à huile")));
        }

        @Test
        @DisplayName("un même élément peut avoir un prix différent par modèle")
        void cree_un_tarif_par_modele() {
            when(tarifRepository.findByElementIdAndModeleId(any(), any())).thenReturn(Optional.empty());

            TarifElementMaintenance spresso = enregistrerTarif.execute(1L, S_PRESSO, BigDecimal.valueOf(1600), null, true);
            TarifElementMaintenance dzire = enregistrerTarif.execute(1L, DZIRE, BigDecimal.valueOf(2200), null, true);

            assertThat(spresso.getPrix()).isEqualByComparingTo("1600");
            assertThat(dzire.getPrix()).isEqualByComparingTo("2200");
            assertThat(dzire.getModeleId()).isEqualTo(DZIRE);
        }

        @Test
        @DisplayName("enregistrer de nouveau met à jour le tarif existant")
        void met_a_jour_le_tarif_existant() {
            when(tarifRepository.findByElementIdAndModeleId(1L, S_PRESSO))
                    .thenReturn(Optional.of(tarif(10L, 1L, S_PRESSO, 1600, null, true)));

            TarifElementMaintenance maj = enregistrerTarif.execute(1L, S_PRESSO, BigDecimal.valueOf(1800), null, false);

            assertThat(maj.getId()).isEqualTo(10L);
            assertThat(maj.getPrix()).isEqualByComparingTo("1800");
            assertThat(maj.isActif()).isFalse();
        }

        @Test
        @DisplayName("un prix négatif est refusé")
        void refuse_un_prix_negatif() {
            when(tarifRepository.findByElementIdAndModeleId(1L, S_PRESSO)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> enregistrerTarif.execute(1L, S_PRESSO, BigDecimal.valueOf(-1), null, true))
                    .isInstanceOf(IllegalArgumentException.class);
            verify(tarifRepository, never()).save(any());
        }

        @Test
        @DisplayName("un modèle inconnu est signalé")
        void refuse_un_modele_inconnu() {
            when(modeleRepository.findById(999L)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> enregistrerTarif.execute(1L, 999L, null, null, true))
                    .isInstanceOf(ResourceNotFoundException.class);
        }

        @Test
        @DisplayName("une image remplacée est effacée quand plus aucun modèle ne s'en sert")
        void efface_l_image_orpheline() {
            when(tarifRepository.findByElementIdAndModeleId(1L, S_PRESSO))
                    .thenReturn(Optional.of(tarif(10L, 1L, S_PRESSO, null, "img/ancienne.png", true)));
            when(tarifRepository.compterParImage("img/ancienne.png")).thenReturn(0L);

            enregistrerTarif.execute(1L, S_PRESSO, null, "img/nouvelle.png", true);

            verify(storage).delete("img/ancienne.png");
        }

        @Test
        @DisplayName("une image partagée avec un autre modèle n'est pas effacée")
        void garde_l_image_partagee() {
            when(tarifRepository.findByElementIdAndModeleId(1L, S_PRESSO))
                    .thenReturn(Optional.of(tarif(10L, 1L, S_PRESSO, null, "img/commune.png", true)));
            when(tarifRepository.compterParImage("img/commune.png")).thenReturn(1L);

            enregistrerTarif.execute(1L, S_PRESSO, null, "img/nouvelle.png", true);

            verify(storage, never()).delete(any());
        }

        @Test
        @DisplayName("retirer un élément d'un modèle supprime son tarif et nettoie son image")
        void supprime_un_tarif() {
            when(tarifRepository.findByElementIdAndModeleId(1L, DZIRE))
                    .thenReturn(Optional.of(tarif(20L, 1L, DZIRE, 2200, "img/dzire.png", true)));
            when(tarifRepository.compterParImage("img/dzire.png")).thenReturn(0L);

            supprimerTarif.execute(1L, DZIRE);

            verify(tarifRepository).deleteById(20L);
            verify(storage).delete("img/dzire.png");
        }

        @Test
        @DisplayName("retirer un tarif absent est signalé")
        void supprime_un_tarif_absent() {
            when(tarifRepository.findByElementIdAndModeleId(1L, DZIRE)).thenReturn(Optional.empty());

            assertThatThrownBy(() -> supprimerTarif.execute(1L, DZIRE))
                    .isInstanceOf(ResourceNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("Reprise pour un nouveau modèle")
    class Copie {

        @Test
        @DisplayName("le modèle cible reçoit les éléments qu'il n'a pas, avec prix et images")
        void copie_les_elements_manquants() {
            when(tarifRepository.findByModeleId(S_PRESSO)).thenReturn(List.of(
                    tarif(10L, 1L, S_PRESSO, 2000, "img/a.png", true),
                    tarif(11L, 2L, S_PRESSO, 5500, null, true)));
            when(tarifRepository.findByModeleId(DZIRE)).thenReturn(List.of(
                    tarif(20L, 2L, DZIRE, 6000, null, true)));

            int copies = copierTarifs.execute(S_PRESSO, DZIRE, true, true);

            assertThat(copies).isEqualTo(1);
            ArgumentCaptor<TarifElementMaintenance> captor = ArgumentCaptor.forClass(TarifElementMaintenance.class);
            verify(tarifRepository).save(captor.capture());
            assertThat(captor.getValue().getElementId()).isEqualTo(1L);
            assertThat(captor.getValue().getModeleId()).isEqualTo(DZIRE);
            assertThat(captor.getValue().getPrix()).isEqualByComparingTo("2000");
            assertThat(captor.getValue().getImage()).isEqualTo("img/a.png");
        }

        @Test
        @DisplayName("sans les prix ni les images, seuls les éléments sont repris")
        void copie_sans_prix_ni_images() {
            when(tarifRepository.findByModeleId(S_PRESSO)).thenReturn(List.of(
                    tarif(10L, 1L, S_PRESSO, 2000, "img/a.png", true)));
            when(tarifRepository.findByModeleId(DZIRE)).thenReturn(List.of());

            copierTarifs.execute(S_PRESSO, DZIRE, false, false);

            ArgumentCaptor<TarifElementMaintenance> captor = ArgumentCaptor.forClass(TarifElementMaintenance.class);
            verify(tarifRepository).save(captor.capture());
            assertThat(captor.getValue().getPrix()).isNull();
            assertThat(captor.getValue().getImage()).isNull();
        }

        @Test
        @DisplayName("copier un modèle sur lui-même est refusé")
        void refuse_le_meme_modele() {
            assertThatThrownBy(() -> copierTarifs.execute(S_PRESSO, S_PRESSO, true, true))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    @DisplayName("Suppression d'un élément")
    class Suppression {

        @Test
        @DisplayName("un élément déjà utilisé dans des maintenances ne se supprime pas")
        void refuse_si_utilise() {
            when(repository.findById(1L)).thenReturn(Optional.of(element(1L, "Filtre")));
            when(repository.isReferencedByElementMaintenance(1L)).thenReturn(true);

            assertThatThrownBy(() -> deleteUseCase.execute(1L)).isInstanceOf(IllegalStateException.class);
            verify(repository, never()).deleteById(any());
        }

        @Test
        @DisplayName("l'élément part avec ses tarifs, et leurs images si personne d'autre ne s'en sert")
        void supprime_avec_ses_tarifs() {
            when(repository.findById(1L)).thenReturn(Optional.of(element(1L, "Filtre")));
            when(tarifRepository.findByElementId(1L)).thenReturn(List.of(
                    tarif(10L, 1L, S_PRESSO, null, "img/a.png", true),
                    tarif(20L, 1L, DZIRE, null, "img/a.png", true)));
            when(tarifRepository.compterParImage("img/a.png")).thenReturn(0L);

            deleteUseCase.execute(1L);

            verify(tarifRepository, times(2)).deleteById(any());
            verify(repository).deleteById(1L);
            verify(storage, times(1)).delete("img/a.png");
        }
    }
}
