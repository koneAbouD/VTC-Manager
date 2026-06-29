package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Recalcule et persiste le statut d'un véhicule à partir de ses signaux métier
 * (immobilisation pénalité active, maintenance en cours, affectation chauffeur).
 * Respecte le statut manuel verrouillant (IMMOBILISE pour panne, HORS_PARC).
 * Ne sauvegarde que si le statut change effectivement.
 */
@RequiredArgsConstructor
public class RecomputeVehiculeStatusUseCase {

    private final VehiculeRepository vehiculeRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final MaintenanceRepository maintenanceRepository;
    private final LignePenaliteRepository lignePenaliteRepository;

    @Transactional
    public void execute(Long vehiculeId) {
        if (vehiculeId == null) return;

        Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        boolean immobilisationActive =
                lignePenaliteRepository.hasImmobilisationActiveByVehiculeId(vehiculeId);
        boolean maintenanceEnCours =
                maintenanceRepository.existsByVehiculeIdAndStatut(vehiculeId, MaintenanceStatus.EN_COURS);
        boolean chauffeurAffecte =
                chauffeurRepository.existsByVehiculeId(vehiculeId);

        VehiculeStatus avant = vehicule.getStatut();
        vehicule.appliquerStatutCalcule(immobilisationActive, maintenanceEnCours, chauffeurAffecte);

        if (vehicule.getStatut() != avant) {
            vehiculeRepository.save(vehicule);
        }
    }
}
