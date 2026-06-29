package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.IndisponibiliteNettoyageService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class UnassignVehiculeFromChauffeurUseCase {

    private final ChauffeurRepository chauffeurRepository;
    private final VehiculeRepository vehiculeRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;
    private final IndisponibiliteNettoyageService indisponibiliteNettoyageService;
    private final VehiculeStatutEventPublisher statutEventPublisher;
    private final ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;

    @Transactional
    public Chauffeur execute(Long chauffeurId) {
        Chauffeur chauffeur = chauffeurRepository.findById(chauffeurId)
                .orElseThrow(() -> new ChauffeurNotFoundException(chauffeurId));

        Vehicule vehicule = chauffeur.getVehicule();
        final Long vehiculeId = vehicule != null ? vehicule.getId() : null;

        if (vehiculeId != null) {
            programmeTravailRepository.findByVehiculeId(vehiculeId).ifPresent(programme -> {
                programme.getChauffeurs().removeIf(pc -> chauffeurId.equals(pc.getChauffeurId()));
                programmeTravailRepository.save(programme);
            });
        }

        chauffeur.unassignVehicule();
        Chauffeur saved = chauffeurRepository.save(chauffeur);

        // Le chauffeur ne conduit plus : clôturer/annuler ses indisponibilités
        // devenues sans effet.
        indisponibiliteNettoyageService.nettoyerSiOrphelin(chauffeurId);

        // Le véhicule n'est plus affecté : recalcul du statut (→ DISPONIBLE, sauf
        // maintenance/immobilisation en cours).
        statutEventPublisher.publishStatutDirty(vehiculeId);
        // Le chauffeur n'est plus affecté : recalcul (→ ACTIF, sauf congé).
        chauffeurStatutEventPublisher.publishStatutDirty(chauffeurId);

        return saved;
    }
}
