package com.tmk.vtcmanager.application.usecases.etatparc;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
import com.tmk.vtcmanager.application.domain.chauffeur.TypePermis;
import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutHistorique;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutMotif;
import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeStatutHistoriqueRepository;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import com.tmk.vtcmanager.interfaces.rest.etatparc.dto.EtatParcSummaryResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GetEtatParcUseCaseTest {

    private VehiculeRepository vehiculeRepository;
    private VehiculeStatutHistoriqueRepository historiqueRepository;
    private DocumentRepository documentRepository;
    private IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private VidangeRepository vidangeRepository;
    private MaintenanceRepository maintenanceRepository;
    private GetEtatParcUseCase useCase;

    @BeforeEach
    void setUp() {
        vehiculeRepository = mock(VehiculeRepository.class);
        historiqueRepository = mock(VehiculeStatutHistoriqueRepository.class);
        documentRepository = mock(DocumentRepository.class);
        indisponibiliteVehiculeRepository = mock(IndisponibiliteVehiculeRepository.class);
        vidangeRepository = mock(VidangeRepository.class);
        maintenanceRepository = mock(MaintenanceRepository.class);
        useCase = new GetEtatParcUseCase(vehiculeRepository, historiqueRepository,
                documentRepository, indisponibiliteVehiculeRepository, vidangeRepository,
                maintenanceRepository);
        when(historiqueRepository.findAllEnCours()).thenReturn(List.of());
        when(documentRepository.findAll()).thenReturn(List.of());
        when(vidangeRepository.findDernieresParVehicule()).thenReturn(List.of());
        when(maintenanceRepository.findByDatePrevueLessThanEqualAndStatut(any(), any()))
                .thenReturn(List.of());
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
        Vehicule v1 = vehicule(1, VehiculeStatus.EN_SERVICE);
        Vehicule v2 = vehicule(2, VehiculeStatus.EN_SERVICE);
        when(vehiculeRepository.findAll()).thenReturn(List.of(v1, v2));

        // Une seule maintenance PLANIFIEE due sous 7 j (véhicule 1) ; celle du
        // véhicule 2 est planifiée dans 30 j → hors horizon.
        when(maintenanceRepository.findByDatePrevueLessThanEqualAndStatut(
                today.plusDays(7), MaintenanceStatus.PLANIFIEE))
                .thenReturn(List.of(
                        Maintenance.builder().vehicule(v1).datePrevue(today.plusDays(5))
                                .statut(MaintenanceStatus.PLANIFIEE).build()));

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
        assertThat(r.alertes().vidangesDues()).isZero();
    }

    @Test
    void lesMaintenancesPrevuesEntrentDansLesExceptionsSurLeMemeHorizonQueLAlerte() {
        LocalDate today = LocalDate.now();
        // 1 : EN_SERVICE, maintenance dans 6 j → entre dans la liste (horizon 7 j)
        Vehicule v1 = vehicule(1, VehiculeStatus.EN_SERVICE);
        // 2 : déjà listé au titre de son statut → une seconde ligne, sur son motif
        // de maintenance prévue (un véhicule porte une ligne par action à mener)
        Vehicule v2 = vehicule(2, VehiculeStatus.EN_MAINTENANCE);
        // 3 : HORS_PARC → exclu de la liste comme du compteur
        Vehicule v3 = vehicule(3, VehiculeStatus.HORS_PARC);
        when(vehiculeRepository.findAll()).thenReturn(List.of(v1, v2, v3));
        when(historiqueRepository.findAllEnCours()).thenReturn(List.of(
                periode(2, VehiculeStatus.EN_MAINTENANCE,
                        VehiculeStatutMotif.MAINTENANCE_EN_COURS, 2)));

        when(maintenanceRepository.findByDatePrevueLessThanEqualAndStatut(
                today.plusDays(7), MaintenanceStatus.PLANIFIEE))
                .thenReturn(List.of(
                        maintenancePlanifiee(v1, today.plusDays(6)),
                        // Deuxième échéance proche du même véhicule : une seule
                        // ligne de maintenance prévue, un seul compte dans l'alerte.
                        maintenancePlanifiee(v1, today.plusDays(3)),
                        maintenancePlanifiee(v2, today.plusDays(1)),
                        maintenancePlanifiee(v3, today.plusDays(2))));

        EtatParcSummaryResponse r = useCase.execute(null, null);

        // v2 (statut), puis les maintenances prévues par échéance croissante :
        // v2 (+1 j) et v1 (+3 j). v3 HORS_PARC est absent des deux blocs.
        assertThat(r.exceptions()).hasSize(3);
        assertThat(r.exceptions().get(0).vehiculeId()).isEqualTo(2L);
        assertThat(r.exceptions().get(0).motif())
                .isEqualTo(VehiculeStatutMotif.MAINTENANCE_EN_COURS.name());
        assertThat(r.exceptions().get(1).vehiculeId()).isEqualTo(2L);
        assertThat(r.exceptions().get(1).motif())
                .isEqualTo(VehiculeStatutMotif.MAINTENANCE_PREVUE.name());
        assertThat(r.exceptions().get(2).vehiculeId()).isEqualTo(1L);
        assertThat(r.exceptions().get(2).motif())
                .isEqualTo(VehiculeStatutMotif.MAINTENANCE_PREVUE.name());
        // La ligne retenue est la plus proche des deux échéances de v1.
        assertThat(r.exceptions().get(2).dateMaintenancePrevue()).isEqualTo(today.plusDays(3));
        // Même horizon et même unité côté alerte : 2 véhicules du parc actif
        // (v1 compté une seule fois malgré ses deux échéances).
        assertThat(r.alertes().maintenancesDuesSous7Jours()).isEqualTo(2);
    }

    @Test
    void lesVidangesDuesEntrentDansLesExceptionsMemeSurUnVehiculeDejaListe() {
        LocalDate today = LocalDate.now();
        // 1 : EN_SERVICE, vidange due par date → entre au motif VIDANGE_DUE
        Vehicule dueDate = vehiculeAvecKm(1, VehiculeStatus.EN_SERVICE, 40_000);
        // 2 : EN_SERVICE, vidange due par kilométrage (300 km restants)
        Vehicule dueKm = vehiculeAvecKm(2, VehiculeStatus.EN_SERVICE, 99_700);
        // 3 : immobilisé ET à vidanger → une ligne par motif
        Vehicule immobilise = vehiculeAvecKm(3, VehiculeStatus.IMMOBILISE, 99_700);
        // 4 : HORS_PARC → exclu de la liste comme du compteur
        Vehicule horsParc = vehiculeAvecKm(4, VehiculeStatus.HORS_PARC, 99_900);
        when(vehiculeRepository.findAll())
                .thenReturn(List.of(dueDate, dueKm, immobilise, horsParc));
        when(historiqueRepository.findAllEnCours()).thenReturn(List.of(
                periode(3, VehiculeStatus.IMMOBILISE,
                        VehiculeStatutMotif.PANNE_OU_ACCIDENT, 5)));
        when(vidangeRepository.findDernieresParVehicule()).thenReturn(List.of(
                vidange(1, today.plusDays(2), 200_000),
                vidange(2, null, 100_000),
                vidange(3, null, 100_000),
                vidange(4, null, 100_000)));

        EtatParcSummaryResponse r = useCase.execute(null, null);

        // Immobilisé (statut) d'abord, puis les trois vidanges dues — le véhicule
        // immobilisé y compris : sa vidange reste à faire.
        assertThat(r.exceptions()).hasSize(4);
        assertThat(r.exceptions().get(0).vehiculeId()).isEqualTo(3L);
        assertThat(r.exceptions().get(0).motif())
                .isEqualTo(VehiculeStatutMotif.PANNE_OU_ACCIDENT.name());
        // Échéance datée avant celles dues au seul kilométrage.
        assertThat(r.exceptions().get(1).vehiculeId()).isEqualTo(1L);
        assertThat(r.exceptions().get(1).motif())
                .isEqualTo(VehiculeStatutMotif.VIDANGE_DUE.name());
        assertThat(r.exceptions().get(1).dateProchaineVidange()).isEqualTo(today.plusDays(2));
        assertThat(r.exceptions().get(2).vehiculeId()).isEqualTo(2L);
        assertThat(r.exceptions().get(2).kmRestantVidange()).isEqualTo(300);
        assertThat(r.exceptions().get(3).vehiculeId()).isEqualTo(3L);
        assertThat(r.exceptions().get(3).motif())
                .isEqualTo(VehiculeStatutMotif.VIDANGE_DUE.name());
        // L'alerte recouvre exactement le bloc vidange de la liste.
        assertThat(r.alertes().vidangesDues()).isEqualTo(3);
    }

    @Test
    void compteLesVidangesDuesParDateOuKilometrage() {
        LocalDate today = LocalDate.now();
        // 1 : due par kilométrage (200 km restants ≤ 500)
        Vehicule dueKm = vehiculeAvecKm(1, VehiculeStatus.EN_SERVICE, 99_800);
        // 2 : due par date (prochaine dans 3 j) ; km encore loin
        Vehicule dueDate = vehiculeAvecKm(2, VehiculeStatus.EN_SERVICE, 40_000);
        // 3 : ni date proche ni km proche → pas d'alerte
        Vehicule nonDue = vehiculeAvecKm(3, VehiculeStatus.EN_SERVICE, 100_000);
        // 4 : km atteint mais HORS_PARC → exclu
        Vehicule horsParc = vehiculeAvecKm(4, VehiculeStatus.HORS_PARC, 99_900);
        when(vehiculeRepository.findAll())
                .thenReturn(List.of(dueKm, dueDate, nonDue, horsParc));

        when(vidangeRepository.findDernieresParVehicule()).thenReturn(List.of(
                vidange(1, null, 100_000),                 // cible km 100 000
                vidange(2, today.plusDays(3), 200_000),    // cible date proche
                vidange(3, today.plusDays(60), 200_000),   // rien de proche
                vidange(4, null, 100_000)));               // HORS_PARC, ignoré

        EtatParcSummaryResponse r = useCase.execute(null, null);

        assertThat(r.alertes().vidangesDues()).isEqualTo(2);
    }

    private Vehicule vehiculeAvecKm(long id, VehiculeStatus statut, int kilometrage) {
        return Vehicule.builder()
                .id(id).immatriculation("IMM-" + id).statut(statut)
                .kilometrage(kilometrage).build();
    }

    private Vidange vidange(long vehiculeId, LocalDate dateProchaine, Integer kmProchaine) {
        return Vidange.builder()
                .vehiculeId(vehiculeId)
                .dateVidange(LocalDate.now().minusMonths(3))
                .kilometrageVidange(0)
                .dateProchaineVidange(dateProchaine)
                .kilometrageProchaineVidange(kmProchaine)
                .build();
    }

    private Maintenance maintenancePlanifiee(Vehicule vehicule, LocalDate datePrevue) {
        return Maintenance.builder()
                .vehicule(vehicule).datePrevue(datePrevue)
                .statut(MaintenanceStatus.PLANIFIEE).build();
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
