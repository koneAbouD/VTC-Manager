package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteChauffeurUseCase {

    private final ChauffeurRepository chauffeurRepository;

    @Transactional
    public void execute(Long id) {
        chauffeurRepository.findById(id)
                .orElseThrow(() -> new ChauffeurNotFoundException(id));
        chauffeurRepository.deleteById(id);
    }
}
