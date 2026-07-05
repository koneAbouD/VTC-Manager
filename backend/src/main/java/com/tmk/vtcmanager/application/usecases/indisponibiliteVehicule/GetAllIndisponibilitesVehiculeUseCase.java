package com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllIndisponibilitesVehiculeUseCase {

    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;

    public List<IndisponibiliteVehicule> execute(Long vehiculeId) {
        if (vehiculeId != null) return indisponibiliteVehiculeRepository.findByVehiculeId(vehiculeId);
        return indisponibiliteVehiculeRepository.findAll();
    }

    public PageResult<IndisponibiliteVehicule> executePage(Long vehiculeId, int page, int size) {
        return indisponibiliteVehiculeRepository.findPage(vehiculeId, page, size);
    }
}
