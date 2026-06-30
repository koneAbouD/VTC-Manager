package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class TerminerIndisponibiliteUseCase {

    private final IndisponibiliteRepository indisponibiliteRepository;
    private final ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;

    @Transactional
    public Indisponibilite execute(Long id) {
        Indisponibilite existing = indisponibiliteRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité", id));
        // terminer() borne la date de fin à aujourd'hui : le modèle overlay cesse
        // d'appliquer le remplacement dès le lendemain (programme normal rétabli).
        existing.terminer();
        Indisponibilite saved = indisponibiliteRepository.save(existing);

        // Recalcul des statuts : titulaire (sortie d'EN_CONGE) et remplaçant
        // (fin de substitution → sortie d'EN_SERVICE).
        if (saved.getChauffeur() != null) {
            chauffeurStatutEventPublisher.publishStatutDirty(saved.getChauffeur().getId());
        }
        if (saved.getChauffeurRemplacant() != null) {
            chauffeurStatutEventPublisher.publishStatutDirty(saved.getChauffeurRemplacant().getId());
        }
        return saved;
    }
}
