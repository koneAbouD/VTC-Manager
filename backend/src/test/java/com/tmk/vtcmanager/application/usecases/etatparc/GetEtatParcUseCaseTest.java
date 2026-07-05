package com.tmk.vtcmanager.application.usecases.etatparc;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
import com.tmk.vtcmanager.application.domain.chauffeur.TypePermis;
import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutHistorique;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutMotif;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeStatutHistoriqueRepository;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcSummaryResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GetEtatParcUseCaseTest {

    private VehiculeRepository vehiculeRepository;
    private VehiculeStatutHistoriqueRepository historiqueRepository;
    private DocumentRepository documentRepository;
    private IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private GetEtatParcUseCase useCase;

    @BeforeEach
    void setUp() {
        vehiculeRepository = mock(VehiculeRepository.class);
        historiqueRepository = mock(VehiculeStatutHistoriqueRepository.class);
        documentRepository = mock(DocumentRepository.class);
        indisponibiliteVehiculeRepository = mock(IndisponibiliteVehiculeRepository.class);
        useCase = new GetEtatParcUseCase(vehiculeRepository, historiqueRepository,
                documentRepository, indisponibiliteVehiculeRepository);
        when(historiqueRepository.findAllEnCours()).thenReturn(List.of());
        when(documentRepository.findAll()).thenReturn(List.of());
    }

    private Vehicule vehicule(long id, VehiculeStatus statut) {
        return Vehicule.builder().id(id).immatriculation("IMM-" + id).statut(statut).build();
    }

    private Vehicule vehicule(long id, VehiculeStatus statut, Long groupeId, Long activiteId) {
        return Vehicule.builder()
                .id(id).immatriculation("IMM-" + id).statut(statut)
                .groupe(groupeId == null ? null : GroupeVehicule.builder().id(groupeId).build())
                .activite(activiteId == null ? null : TypeActivite.builder().id(activiteId).build())
                .build();
    }

    @Test
    void filtreLeParcParGroupeEtActivite() {
        when(vehiculeRepository.findAll()).thenReturn(List.of(
                vehicule(1, VehiculeStatus.EN_SERVICE, 10L, 100L),
                vehicule(2, VehiculeStatus.DISPONIBLE, 10L, 100L),
                vehicule(3, VehiculeStatus.EN_SERVICE, 20L, 100L),
                vehicule(4, VehiculeStatus.IMMOBILISE, 10L, 200L)));

        // Groupe 10 → véhicules 1, 2, 4 (le 3 est dans le groupe 20)
        EtatParcSummaryResponse parGroupe = useCase.execute(10L, null);
        assertThat(parGroupe.totalVehicules()).isEqualTo(3);
        assertThat(parGroupe.enService()).isEqualTo(1);
        assertThat(parGroupe.disponibles()).isEqualTo(1);
        assertThat(parGroupe.immobilises()).isEqualTo(1);

        // Groupe 10 ET activité 100 → véhicules 1, 2 (le 4 est en activité 200)
        EtatParcSummaryResponse parGroupeEtActivite = useCase.execute(10L, 100L);
        assertThat(parGroupeEtActivite.totalVehicules()).isEqualTo(2);
        assertThat(parGroupeEtActivite.immobilises()).isZero();
    }

    @Test
    void calculeLesTauxSurLeParcActifEnExcluantHorsParc() {
        when(vehiculeRepository.findAll()).thenReturn(List.of(
                vehicule(1, VehiculeStatus.EN_SERVICE),
                vehicule(2, VehiculeStatus.EN_SERVICE),
                vehicule(3, VehiculeStatus.DISPONIBLE),
                vehicule(4, VehiculeStatus.IMMOBILISE),
                vehicule(5, VehiculeStatus.HORS_PARC)));

        EtatParcSummaryResponse r = useCase.execute(null, null);

        assertThat(r.totalVehicules()).isEqualTo(5);
        assertThat(r.parcActif()).isEqualTo(4);
        // (2 EN_SERVICE + 1 DISPONIBLE) / 4 actifs = 75 %
        assertThat(r.tauxDisponibilite()).isEqualByComparingTo(new BigDecimal("75.0"));
        // 2 EN_SERVICE / 4 actifs = 50 %
        assertThat(r.tauxUtilisation()).isEqualByComparingTo(new BigDecimal("50.0"));
    }

    @Test
    void tauxAZeroQuandLeParcActifEstVide() {
        when(vehiculeRepository.findAll()).thenReturn(List.of(
                vehicule(1, VehiculeStatus.HORS_PARC)));

        EtatParcSummaryResponse r = useCase.execute(null, null);

        assertThat(r.parcActif()).isZero();
        assertThat(r.tauxDisponibilite()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(r.tauxUtilisation()).isEqualByComparingTo(BigDecimal.ZERO);
    }

    @Test
    void lesExceptionsIncluentDisponibleCommeAnomalieDouceEtSontTrieesParAnciennete() {
        when(vehiculeRepository.findAll()).thenReturn(List.of(
                vehicule(1, VehiculeStatus.EN_SERVICE),
                vehicule(2, VehiculeStatus.DISPONIBLE),
                vehicule(3, VehiculeStatus.IMMOBILISE),
                vehicule(4, VehiculeStatus.HORS_PARC)));
        when(historiqueRepository.findAllEnCours()).thenReturn(List.of(
                periode(2, VehiculeStatus.DISPONIBLE, VehiculeStatutMotif.SANS_CHAUFFEUR, 9),
                periode(3, VehiculeStatus.IMMOBILISE, VehiculeStatutMotif.PANNE_OU_ACCIDENT, 3)));

        EtatParcSummaryResponse r = useCase.execute(null, null);

        // EN_SERVICE et HORS_PARC ne sont pas des exceptions
        assertThat(r.exceptions()).hasSize(2);
        // Trié par ancienneté décroissante : le DISPONIBLE depuis 9 j en premier
        assertThat(r.exceptions().get(0).vehiculeId()).isEqualTo(2L);
        assertThat(r.exceptions().get(0).motif())
                .isEqualTo(VehiculeStatutMotif.SANS_CHAUFFEUR.name());
        assertThat(r.exceptions().get(0).joursDansStatut()).isEqualTo(9);
        assertThat(r.exceptions().get(1).motif())
                .isEqualTo(VehiculeStatutMotif.PANNE_OU_ACCIDENT.name());
    }

    @Test
    void motifDeduitDuStatutQuandLaPeriodeSeedNEnPortePas() {
        when(vehiculeRepository.findAll()).thenReturn(List.of(
                vehicule(1, VehiculeStatus.DISPONIBLE)));
        when(historiqueRepository.findAllEnCours()).thenReturn(List.of(
                periode(1, VehiculeStatus.DISPONIBLE, null, 2)));

        EtatParcSummaryResponse r = useCase.execute(null, null);

        assertThat(r.exceptions().get(0).motif())
                .isEqualTo(VehiculeStatutMotif.SANS_CHAUFFEUR.name());
    }

    @Test
    void compteLesAlertesPreventives() {
        LocalDate today = LocalDate.now();
        Vehicule maintenanceDue = vehicule(1, VehiculeStatus.EN_SERVICE);
        maintenanceDue.setDateProchaineMaintenance(today.plusDays(5));
        Vehicule maintenanceLointaine = vehicule(2, VehiculeStatus.EN_SERVICE);
        maintenanceLointaine.setDateProchaineMaintenance(today.plusDays(30));
        when(vehiculeRepository.findAll()).thenReturn(List.of(maintenanceDue, maintenanceLointaine));

        when(documentRepository.findAll()).thenReturn(List.of(
                // Assurance qui expire dans 10 jours → alerte
                Document.builder().dateExpiration(today.plusDays(10))
                        .statut(DocumentStatut.VALIDE).cible(CibleDocument.VEHICULE).cibleId(1L).build(),
                // Document qui expire dans 60 jours → hors horizon
                Document.builder().dateExpiration(today.plusDays(60))
                        .statut(DocumentStatut.VALIDE).cible(CibleDocument.VEHICULE).cibleId(1L).build(),
                // Document véhicule déjà expiré → alerte (déjà expirés inclus)
                Document.builder().dateExpiration(today.minusDays(3))
                        .statut(DocumentStatut.EXPIRE).cible(CibleDocument.VEHICULE).cibleId(2L).build(),
                // Permis chauffeur expiré → alerte permis (non double-compté dans documents)
                Document.builder().dateExpiration(today.minusDays(2))
                        .statut(DocumentStatut.EXPIRE).cible(CibleDocument.CHAUFFEUR).cibleId(7L)
                        .categorie(Set.of(TypePermis.B)).build()));

        EtatParcSummaryResponse r = useCase.execute(null, null);

        // 1 expirant sous 30 j + 1 véhicule déjà expiré ; le permis expiré n'est pas recompté ici.
        assertThat(r.alertes().documentsExpirantSous30Jours()).isEqualTo(2);
        assertThat(r.alertes().maintenancesDuesSous7Jours()).isEqualTo(1);
        assertThat(r.alertes().permisExpires()).isEqualTo(1);
    }

    private VehiculeStatutHistorique periode(long vehiculeId, VehiculeStatus statut,
                                             VehiculeStatutMotif motif, int joursDepuis) {
        return VehiculeStatutHistorique.builder()
                .vehiculeId(vehiculeId)
                .statut(statut)
                .motif(motif)
                .dateDebut(LocalDateTime.now().minusDays(joursDepuis))
                .build();
    }
}
