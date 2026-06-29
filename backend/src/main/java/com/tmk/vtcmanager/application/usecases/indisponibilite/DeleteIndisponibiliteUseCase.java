package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteIndisponibiliteUseCase {

    private final IndisponibiliteRepository indisponibiliteRepository;
    private final ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;

    @Transactional
    public void execute(Long id) {
        Indisponibilite existing = indisponibiliteRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité", id));
        Long titulaireId = existing.getChauffeur() != null ? existing.getChauffeur().getId() : null;

        // Modèle overlay : rien à rétablir, la substitution n'est plus calculée
        // dès que l'indisponibilité disparaît.
        indisponibiliteRepository.deleteById(id);

        // La suppression peut faire sortir le titulaire d'EN_CONGE.
        chauffeurStatutEventPublisher.publishStatutDirty(titulaireId);
    }
}
