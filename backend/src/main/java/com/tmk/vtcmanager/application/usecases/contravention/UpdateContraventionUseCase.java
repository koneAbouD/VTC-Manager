package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class UpdateContraventionUseCase {

    private final ContraventionRepository contraventionRepository;

    @Transactional
    public Contravention execute(Long id, Contravention data) {
        Contravention existing = contraventionRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Contravention", id));
        existing.setDateInfraction(data.getDateInfraction());
        existing.setTypeInfraction(data.getTypeInfraction());
        existing.setLieu(data.getLieu());
        existing.setDescription(data.getDescription());
        existing.setMontant(data.getMontant());
        existing.setCotisation(data.getCotisation());
        if (data.getMontantPaye() != null) existing.setMontantPaye(data.getMontantPaye());
        if (data.getStatut() != null) existing.setStatut(data.getStatut());
        existing.setDatePaiement(data.getDatePaiement());
        existing.setChauffeur(data.getChauffeur());
        existing.setVehicule(data.getVehicule());
        return contraventionRepository.save(existing);
    }
}
