package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.ports.persistence.ProgrammeChauffeurAssignmentPort;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ProgrammeChauffeurEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ChauffeurJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ProgrammeChauffeurJpaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@RequiredArgsConstructor
public class ProgrammeChauffeurAssignmentAdapter implements ProgrammeChauffeurAssignmentPort {

    private final ProgrammeChauffeurJpaRepository programmeChauffeurJpaRepository;
    private final ChauffeurJpaRepository chauffeurJpaRepository;

    @Override
    public List<Long> findProgrammeChauffeurIdsByChauffeur(Long chauffeurId) {
        return programmeChauffeurJpaRepository.findByChauffeurId(chauffeurId).stream()
                .map(ProgrammeChauffeurEntity::getId)
                .toList();
    }

    @Override
    public void reassignChauffeur(Long programmeChauffeurId, Long nouveauChauffeurId) {
        programmeChauffeurJpaRepository.findById(programmeChauffeurId).ifPresent(pc -> {
            pc.setChauffeur(chauffeurJpaRepository.getReferenceById(nouveauChauffeurId));
            programmeChauffeurJpaRepository.save(pc);
        });
    }
}
