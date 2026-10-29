package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceFiltres;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.maintenance.SyntheseMaintenances;
import com.tmk.vtcmanager.application.domain.maintenance.TotalMaintenanceParStatut;
import com.tmk.vtcmanager.application.domain.maintenance.TotalMaintenanceParType;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.function.Supplier;

public class GetAllMaintenancesUseCase {

    private final MaintenanceRepository maintenanceRepository;

    /** Jour de référence du retard ; remplaçable en test. */
    private final Supplier<LocalDate> aujourdhui;

    public GetAllMaintenancesUseCase(MaintenanceRepository maintenanceRepository) {
        this(maintenanceRepository, LocalDate::now);
    }

    GetAllMaintenancesUseCase(MaintenanceRepository maintenanceRepository,
                              Supplier<LocalDate> aujourdhui) {
        this.maintenanceRepository = maintenanceRepository;
        this.aujourdhui = aujourdhui;
    }

    public List<Maintenance> execute(Long vehiculeId, LocalDate dateDebut, LocalDate dateFin, MaintenanceStatus statut) {
        if (dateDebut != null || dateFin != null || statut != null) {
            return maintenanceRepository.findByFiltres(dateDebut, dateFin, statut, vehiculeId);
        }
        return vehiculeId == null
                ? maintenanceRepository.findAll()
                : maintenanceRepository.findByVehiculeId(vehiculeId);
    }

    public PageResult<Maintenance> executePage(MaintenanceFiltres filtres, int page, int size) {
        return maintenanceRepository.findPageByFiltres(filtres, aujourdhui.get(), page, size);
    }

    /**
     * Compteurs de l'écran sur la sélection. Chaque groupe de compteurs ignore
     * le filtre qu'il sert à choisir — les tuiles le type, les pastilles le
     * statut et le retard —, sinon cocher l'un ferait tomber les autres à zéro.
     */
    public SyntheseMaintenances synthese(MaintenanceFiltres filtres) {
        MaintenanceFiltres tousStatuts = filtres.sansStatut();

        List<TotalMaintenanceParType> parType = maintenanceRepository
                .totauxParType(tousStatuts.sansType()).stream()
                .sorted(Comparator.comparingLong(TotalMaintenanceParType::nombre).reversed()
                        .thenComparing(TotalMaintenanceParType::libelle,
                                Comparator.nullsLast(Comparator.naturalOrder())))
                .toList();

        // Tous les statuts servis, même sans intervention : une pastille absente
        // de la réponse garderait à l'écran son ancien compteur.
        List<TotalMaintenanceParStatut> trouves = maintenanceRepository.totauxParStatut(tousStatuts);
        List<TotalMaintenanceParStatut> parStatut = Arrays.stream(MaintenanceStatus.values())
                .map(statut -> trouves.stream()
                        .filter(t -> t.statut() == statut)
                        .findFirst()
                        .orElseGet(() -> new TotalMaintenanceParStatut(statut, 0)))
                .toList();

        long enRetard = maintenanceRepository.compter(tousStatuts.seulementEnRetard(), aujourdhui.get());

        return new SyntheseMaintenances(parType, parStatut, enRetard);
    }
}
