package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.TypeVehicule;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.TypeVehiculeRepository;
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

class TypeVehiculeReferentielUseCaseTest {

    private TypeVehiculeRepository repository;
    private TypeVehiculeReferentielUseCase useCase;

    @BeforeEach
    void setUp() {
        repository = mock(TypeVehiculeRepository.class);
        useCase = new TypeVehiculeReferentielUseCase(repository);
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void creer_persiste_un_type_actif_par_defaut() {
        when(repository.existsByNom("TAXI")).thenReturn(false);

        TypeVehicule cree = useCase.creer("TAXI", "Transport de personnes");

        assertThat(cree.getNom()).isEqualTo("TAXI");
        assertThat(cree.isActif()).isTrue();
        verify(repository).save(any(TypeVehicule.class));
    }

    @Test
    void creer_refuse_un_nom_deja_existant() {
        when(repository.existsByNom("TAXI")).thenReturn(true);

        assertThatThrownBy(() -> useCase.creer("TAXI", null))
                .isInstanceOf(ResourceAlreadyExistsException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void mettreAJour_modifie_les_champs() {
        TypeVehicule existant = TypeVehicule.builder().id(3L).nom("TAXI").actif(true).build();
        when(repository.findById(3L)).thenReturn(Optional.of(existant));
        when(repository.findByNom("VTC")).thenReturn(Optional.empty());

        TypeVehicule maj = useCase.mettreAJour(3L, "VTC", "desc");

        assertThat(maj.getNom()).isEqualTo("VTC");
        assertThat(maj.getDescription()).isEqualTo("desc");
    }

    @Test
    void mettreAJour_refuse_un_nom_pris_par_un_autre() {
        when(repository.findById(3L)).thenReturn(
                Optional.of(TypeVehicule.builder().id(3L).nom("TAXI").build()));
        when(repository.findByNom("VTC")).thenReturn(
                Optional.of(TypeVehicule.builder().id(9L).nom("VTC").build()));

        assertThatThrownBy(() -> useCase.mettreAJour(3L, "VTC", null))
                .isInstanceOf(ResourceAlreadyExistsException.class);
    }

    @Test
    void changerActivation_bascule_le_drapeau() {
        when(repository.findById(3L)).thenReturn(
                Optional.of(TypeVehicule.builder().id(3L).nom("TAXI").actif(true).build()));

        TypeVehicule maj = useCase.changerActivation(3L, false);

        assertThat(maj.isActif()).isFalse();
    }

    @Test
    void supprimer_leve_not_found_si_absent() {
        when(repository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> useCase.supprimer(99L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).deleteById(any());
    }

    @Test
    void supprimer_delegue_au_repository() {
        when(repository.existsById(3L)).thenReturn(true);

        useCase.supprimer(3L);

        verify(repository).deleteById(3L);
    }
}
