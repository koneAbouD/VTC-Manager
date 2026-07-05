package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutMotif;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.VehiculeStatutHistoriqueService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

/**
 * Recalcule et persiste le statut d'un véhicule à partir de ses signaux métier
 * (indisponibilité véhicule planifiée, immobilisation pénalité active, maintenance
 * en cours, affectation chauffeur). Respecte le statut manuel verrouillant
 * (IMMOBILISE pour panne, HORS_PARC). Ne sauvegarde que si le statut change
 * effectivement ; chaque transition effective est historisée avec son motif.
 */
@RequiredArgsConstructor
public class RecomputeVehiculeStatusUseCase {

    private final VehiculeRepository vehiculeRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final MaintenanceRepository maintenanceRepository;
    private final LignePenaliteRepository lignePenaliteRepository;
    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private final VehiculeStatutHistoriqueService statutHistoriqueService;

    @Transactional
    public void execute(Long vehiculeId) {
        if (vehiculeId == null) return;

        Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        boolean indisponibiliteActive =
                indisponibiliteVehiculeRepository.isImmobiliseAt(vehiculeId, LocalDate.now());
        boolean immobilisationActive =
                lignePenaliteRepository.hasImmobilisationActiveByVehiculeId(vehiculeId);
        boolean maintenanceEnCours =
                maintenanceRepository.existsByVehiculeIdAndStatut(vehiculeId, MaintenanceStatus.EN_COURS);
        boolean chauffeurAffecte =
                chauffeurRepository.existsByVehiculeId(vehiculeId);

        VehiculeStatus avant = vehicule.getStatut();
        vehicule.appliquerStatutCalcule(indisponibiliteActive, immobilisationActive,
                maintenanceEnCours, chauffeurAffecte);

        if (vehicule.getStatut() != avant) {
            vehiculeRepository.save(vehicule);
            statutHistoriqueService.enregistrerTransition(vehiculeId, vehicule.getStatut(),
                    motifDe(vehicule, indisponibiliteActive, immobilisationActive,
                            maintenanceEnCours, chauffeurAffecte));
        }
    }

    private VehiculeStatutMotif motifDe(Vehicule vehicule,
                                        boolean indisponibiliteActive,
                                        boolean immobilisationActive,
                                        boolean maintenanceEnCours,
                                        boolean chauffeurAffecte) {
        if (vehicule.estVerrouille()) {
            return vehicule.getStatutManuel() == VehiculeStatus.HORS_PARC
                    ? VehiculeStatutMotif.SORTIE_PARC
                    : VehiculeStatutMotif.PANNE_OU_ACCIDENT;
        }
        if (indisponibiliteActive) return VehiculeStatutMotif.IMMOBILISATION_INDISPONIBILITE;
        if (immobilisationActive)  return VehiculeStatutMotif.IMMOBILISATION_PENALITE;
        if (maintenanceEnCours)    return VehiculeStatutMotif.MAINTENANCE_EN_COURS;
        if (chauffeurAffecte)      return VehiculeStatutMotif.CHAUFFEUR_AFFECTE;
        return VehiculeStatutMotif.SANS_CHAUFFEUR;
    }
}
