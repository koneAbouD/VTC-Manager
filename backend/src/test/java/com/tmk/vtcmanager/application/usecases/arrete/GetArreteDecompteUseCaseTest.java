package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.DetteRestanteArrete;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.document.ArreteDocumentRenderer;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
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
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@DisplayName("Décompte PDF : recettes annulées de la période")
class GetArreteDecompteUseCaseTest {

    @Mock private GetArreteUseCase getArreteUseCase;
    @Mock private ArreteDocumentRenderer renderer;
    @Mock private LigneRecetteRepository ligneRecetteRepository;
    @Mock private CalculerCompteCourantUseCase calculerCompteCourantUseCase;
    @Mock private VehiculeRepository vehiculeRepository;
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

    private static final LocalDate DEBUT = LocalDate.of(2000, 1, 1);
    private static final LocalDate FIN = LocalDate.of(2100, 12, 31);

    @Test
    @DisplayName("aperçu : décompte simulé sur la sélection, nommé comme un arrêté enregistré")
    void apercuSurSelection() {
        SelectionArrete selection = new SelectionArrete(Set.of(10L), Set.of());
        ArreteCompte simule = ArreteCompte.builder()
                .perimetre(PerimetreArrete.VEHICULE).perimetreId(7L)
                .periodeDebut(LocalDate.of(2026, 9, 1)).periodeFin(LocalDate.of(2026, 9, 30))
                .lignes(List.of(LigneArrete.builder().document(TypeDocumentCreance.COTISATION)
                        .documentId(10L).vehiculeId(7L).sens(SensArrete.CREDIT).build()))
                .reglements(List.of(ReglementArrete.builder().chauffeurId(3L).chauffeurNom("Kouassi").build()))
                .dettesRestantes(List.of(DetteRestanteArrete.builder().vehiculeId(7L).build()))
                .build();
        when(calculerCompteCourantUseCase.simuler(PerimetreArrete.VEHICULE, 7L, DEBUT, FIN, selection))
                .thenReturn(simule);
        when(vehiculeRepository.findById(7L))
                .thenReturn(Optional.of(Vehicule.builder().immatriculation("1234-AB-01").build()));
        when(ligneRecetteRepository.findByCriteres(any())).thenReturn(List.of());

        useCase.apercu(PerimetreArrete.VEHICULE, 7L, DEBUT, FIN, selection);

        assertThat(simule.getPerimetreLibelle()).isEqualTo("1234-AB-01");
        assertThat(simule.getLignes().get(0).getImmatriculation()).isEqualTo("1234-AB-01");
        assertThat(simule.getDettesRestantes().get(0).getImmatriculation()).isEqualTo("1234-AB-01");
        verify(renderer).renderDecomptePdf(eq(simule), eq(List.of()));
    }

    @Test
    @DisplayName("aperçu sans cotisation cochée : refusé, aucun PDF")
    void apercuSansCotisation() {
        SelectionArrete selection = new SelectionArrete(Set.of(), null);
        when(calculerCompteCourantUseCase.simuler(PerimetreArrete.CHAUFFEUR, 3L, DEBUT, FIN, selection))
                .thenReturn(ArreteCompte.builder().perimetre(PerimetreArrete.CHAUFFEUR).perimetreId(3L).build());

        assertThatThrownBy(() -> useCase.apercu(PerimetreArrete.CHAUFFEUR, 3L, DEBUT, FIN, selection))
                .isInstanceOf(IllegalArgumentException.class);
        verify(renderer, never()).renderDecomptePdf(any(), any());
    }
}
