package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.document.ArreteDocumentRenderer;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@DisplayName("Décompte PDF : recettes annulées de la période")
class GetArreteDecompteUseCaseTest {

    @Mock private GetArreteUseCase getArreteUseCase;
    @Mock private ArreteDocumentRenderer renderer;
    @Mock private LigneRecetteRepository ligneRecetteRepository;
    @InjectMocks private GetArreteDecompteUseCase useCase;

    private static ArreteCompte arrete(PerimetreArrete perimetre) {
        // Bornes resserrées d'un arrêté ancien : la recherche couvre quand même le mois.
        return ArreteCompte.builder().id(1L).perimetre(perimetre).perimetreId(7L)
                .periodeDebut(LocalDate.of(2026, 9, 4)).periodeFin(LocalDate.of(2026, 9, 27)).build();
    }

    @Test
    @DisplayName("arrêté par véhicule : recettes annulées du véhicule, du 1er au dernier jour du mois, triées par date")
    void parVehicule() {
        ArreteCompte a = arrete(PerimetreArrete.VEHICULE);
        LigneRecette r20 = LigneRecette.builder().id(2L).dateRecette(LocalDate.of(2026, 9, 20)).build();
        LigneRecette r3 = LigneRecette.builder().id(1L).dateRecette(LocalDate.of(2026, 9, 3)).build();
        when(getArreteUseCase.detail(1L)).thenReturn(Optional.of(a));
        when(ligneRecetteRepository.findByCriteres(any())).thenReturn(List.of(r20, r3));

        useCase.executer(1L);

        ArgumentCaptor<LigneRecetteFiltres> filtres = ArgumentCaptor.forClass(LigneRecetteFiltres.class);
        verify(ligneRecetteRepository).findByCriteres(filtres.capture());
        assertThat(filtres.getValue().getVehiculeId()).isEqualTo(7L);
        assertThat(filtres.getValue().getChauffeurId()).isNull();
        assertThat(filtres.getValue().getStatut()).isEqualTo(StatutLigneRecette.ANNULEE);
        assertThat(filtres.getValue().getDateDebut()).isEqualTo(LocalDate.of(2026, 9, 1));
        assertThat(filtres.getValue().getDateFin()).isEqualTo(LocalDate.of(2026, 9, 30));
        verify(renderer).renderDecomptePdf(eq(a), eq(List.of(r3, r20)));
    }

    @Test
    @DisplayName("arrêté par chauffeur : recettes annulées du chauffeur")
    void parChauffeur() {
        when(getArreteUseCase.detail(1L)).thenReturn(Optional.of(arrete(PerimetreArrete.CHAUFFEUR)));
        when(ligneRecetteRepository.findByCriteres(any())).thenReturn(List.of());

        useCase.executer(1L);

        ArgumentCaptor<LigneRecetteFiltres> filtres = ArgumentCaptor.forClass(LigneRecetteFiltres.class);
        verify(ligneRecetteRepository).findByCriteres(filtres.capture());
        assertThat(filtres.getValue().getChauffeurId()).isEqualTo(7L);
        assertThat(filtres.getValue().getVehiculeId()).isNull();
    }
}
