package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.util.List;

@RequiredArgsConstructor
public class GetAllContraventionsUseCase {

    private final ContraventionRepository contraventionRepository;

    public List<Contravention> execute(Long chauffeurId, Long vehiculeId) {
        if (chauffeurId != null) return contraventionRepository.findByChauffeurId(chauffeurId);
        if (vehiculeId != null) return contraventionRepository.findByVehiculeId(vehiculeId);
        return contraventionRepository.findAll();
    }

    public PageResult<Contravention> executePage(Long chauffeurId, Long vehiculeId,
                                                 LocalDate dateDebut, LocalDate dateFin,
                                                 int page, int size) {
        return contraventionRepository.findPage(chauffeurId, vehiculeId, dateDebut, dateFin, page, size);
    }
}
