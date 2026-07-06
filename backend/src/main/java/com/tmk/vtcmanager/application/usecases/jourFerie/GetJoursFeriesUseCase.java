package com.tmk.vtcmanager.application.usecases.jourFerie;

import com.tmk.vtcmanager.application.domain.jourFerie.JourFerie;
import com.tmk.vtcmanager.application.ports.persistence.JourFerieRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetJoursFeriesUseCase {

    private final JourFerieRepository repository;

    public List<JourFerie> execute(int annee) {
        return repository.findByAnnee(annee);
    }
}
