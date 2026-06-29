package com.tmk.vtcmanager.application.usecases.conditionTravail;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/// Calcule l'impact (avant application) d'une modification de condition de
/// travail : combien de véhicules l'utilisent et combien d'indisponibilités
/// en cours / planifiées de leurs chauffeurs sont potentiellement concernées.
@RequiredArgsConstructor
public class GetConditionTravailImpactUseCase {

    private final VehiculeRepository vehiculeRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;
    private final IndisponibiliteRepository indisponibiliteRepository;

    public record Impact(int vehicules, int indisponibilites) {}

    public Impact execute(Long conditionTravailId) {
        List<Vehicule> vehicules = vehiculeRepository.findByConditionTravailId(conditionTravailId);

        Set<Long> chauffeurIds = new HashSet<>();
        for (Vehicule v : vehicules) {
            programmeTravailRepository.findByVehiculeId(v.getId()).ifPresent(p -> {
                if (p.getChauffeurs() != null) {
                    p.getChauffeurs().forEach(pc -> {
                        if (pc.getChauffeurId() != null) chauffeurIds.add(pc.getChauffeurId());
                    });
                }
            });
        }

        int indisponibilites = 0;
        for (Long chauffeurId : chauffeurIds) {
            indisponibilites += (int) indisponibiliteRepository.findByChauffeurId(chauffeurId).stream()
                    .filter(i -> i.getStatut() == IndisponibiliteStatut.EN_COURS
                            || i.getStatut() == IndisponibiliteStatut.PLANIFIEE)
                    .count();
        }

        return new Impact(vehicules.size(), indisponibilites);
    }
}
