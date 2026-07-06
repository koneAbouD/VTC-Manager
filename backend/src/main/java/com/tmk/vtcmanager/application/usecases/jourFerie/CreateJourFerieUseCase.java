package com.tmk.vtcmanager.application.usecases.jourFerie;

import com.tmk.vtcmanager.application.domain.jourFerie.JourFerie;
import com.tmk.vtcmanager.application.domain.jourFerie.SourceJourFerie;
import com.tmk.vtcmanager.application.ports.persistence.JourFerieRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class CreateJourFerieUseCase {

    private final JourFerieRepository repository;

    /** Ajout/confirmation manuelle (fêtes musulmanes, décrets exceptionnels). */
    public JourFerie execute(JourFerie jourFerie) {
        jourFerie.setSource(SourceJourFerie.MANUEL);
        jourFerie.validate();
        jourFerie.normalize();
        if (repository.existsByDate(jourFerie.getDate())) {
            throw new IllegalArgumentException(
                    "Un jour férié existe déjà à la date " + jourFerie.getDate() + ".");
        }
        return repository.save(jourFerie);
    }
}
