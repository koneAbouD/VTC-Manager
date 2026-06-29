package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class TerminerIndisponibiliteUseCase {

    private final IndisponibiliteRepository indisponibiliteRepository;

    @Transactional
    public Indisponibilite execute(Long id) {
        Indisponibilite existing = indisponibiliteRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité", id));
        // terminer() borne la date de fin à aujourd'hui : le modèle overlay cesse
        // d'appliquer le remplacement dès le lendemain (programme normal rétabli).
        existing.terminer();
        return indisponibiliteRepository.save(existing);
    }
}
