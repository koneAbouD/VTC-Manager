package com.tmk.vtcmanager.application.usecases.jourFerie;

import com.tmk.vtcmanager.application.ports.persistence.JourFerieRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class DeleteJourFerieUseCase {

    private final JourFerieRepository repository;

    public void execute(Long id) {
        repository.deleteById(id);
    }
}
