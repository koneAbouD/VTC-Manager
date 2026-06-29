package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteIndisponibiliteUseCase {

    private final IndisponibiliteRepository indisponibiliteRepository;

    @Transactional
    public void execute(Long id) {
        indisponibiliteRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité", id));
        // Modèle overlay : rien à rétablir, la substitution n'est plus calculée
        // dès que l'indisponibilité disparaît.
        indisponibiliteRepository.deleteById(id);
    }
}
