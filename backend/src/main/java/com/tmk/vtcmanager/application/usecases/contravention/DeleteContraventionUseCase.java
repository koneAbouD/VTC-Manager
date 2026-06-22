package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteContraventionUseCase {

    private final ContraventionRepository contraventionRepository;

    @Transactional
    public void execute(Long id) {
        contraventionRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Contravention", id));
        contraventionRepository.deleteById(id);
    }
}
