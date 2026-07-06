package com.tmk.vtcmanager.application.usecases.jourFerie;

import com.tmk.vtcmanager.application.domain.jourFerie.JourFerie;
import com.tmk.vtcmanager.application.ports.persistence.JourFerieRepository;
import com.tmk.vtcmanager.application.services.JoursFeriesCalculator;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/**
 * Alimente la table des jours fériés d'une année avec les fériés déterministes
 * (fixes + chrétiens). Idempotent : n'écrase pas les dates déjà présentes (dont
 * les fêtes musulmanes confirmées à la main).
 */
@RequiredArgsConstructor
public class SeedJoursFeriesUseCase {

    private final JourFerieRepository repository;
    private final JoursFeriesCalculator calculator;

    @Transactional
    public List<JourFerie> execute(int annee) {
        List<JourFerie> crees = new ArrayList<>();
        for (JourFerie ferie : calculator.genererAnnee(annee)) {
            if (repository.existsByDate(ferie.getDate())) {
                continue; // déjà présent (auto d'un run précédent ou saisie manuelle)
            }
            ferie.normalize();
            crees.add(repository.save(ferie));
        }
        return crees;
    }
}
