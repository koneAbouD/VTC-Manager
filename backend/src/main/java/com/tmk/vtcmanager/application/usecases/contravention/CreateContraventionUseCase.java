package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class CreateContraventionUseCase {

    private final ContraventionRepository contraventionRepository;

    @Transactional
    public Contravention execute(Contravention contravention) {
        contravention.initializeDefaults();
        return contraventionRepository.save(contravention);
    }
}
