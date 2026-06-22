package com.tmk.vtcmanager.application.usecases.groupe;

import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetAllGroupesUseCase {

    private final GroupeVehiculeRepository groupeVehiculeRepository;
    private final VehiculeRepository vehiculeRepository;

    public List<GroupeVehicule> execute() {
        List<GroupeVehicule> groupes = groupeVehiculeRepository.findAll();
        groupes.forEach(g -> g.setNbVehicules(
                (int) vehiculeRepository.countByGroupeId(g.getId())
        ));
        return groupes;
    }
}