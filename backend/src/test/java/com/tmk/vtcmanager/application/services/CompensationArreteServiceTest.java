package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@DisplayName("Marquage des versements compensés par un arrêté")
class CompensationArreteServiceTest {

    private final ArreteCompteRepository repository = mock(ArreteCompteRepository.class);
    private final CompensationArreteService service = new CompensationArreteService(repository);

    @Test
    @DisplayName("seul le versement rattaché à un arrêté porte sa référence")
    void marqueLaCompensation() {
        Encaissement guichet = Encaissement.builder().id(1L).operationFinanciereId(10L).build();
        Encaissement compensation = Encaissement.builder().id(2L).operationFinanciereId(20L).build();
        Encaissement herite = Encaissement.builder().id(3L).build();
        LigneRecette ligne = LigneRecette.builder()
                .encaissements(new ArrayList<>(List.of(guichet, compensation, herite))).build();
        when(repository.referencesArreteParOperationCompensation(List.of(10L, 20L)))
                .thenReturn(Map.of(20L, "ARR-2026-000004"));

        service.marquer(ligne);

        assertThat(guichet.getArreteCompensation()).isNull();
        assertThat(compensation.getArreteCompensation()).isEqualTo("ARR-2026-000004");
        assertThat(herite.getArreteCompensation()).isNull();
    }

    @Test
    @DisplayName("une ligne sans versement ne coûte aucune requête")
    void sansVersement() {
        service.marquer(LigneRecette.builder().encaissements(new ArrayList<>()).build());

        verify(repository, never()).referencesArreteParOperationCompensation(anyCollection());
    }
}
