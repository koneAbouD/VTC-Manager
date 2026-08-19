package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Écarts de caisse qui attendent encore une décision, toutes caisses
 * confondues.
 *
 * <p>Un écart constaté au comptage dort en compte d'attente : la trésorerie est
 * réalignée sur ce qui a été compté, mais le résultat n'est pas touché tant que
 * personne n'a dit d'où vient la différence. Tant qu'il en reste un, le mois où
 * il tombe refuse d'être clôturé — publier un résultat qu'on sait incomplet
 * n'aurait pas de sens.
 *
 * <p>Les retrouver un par un dans l'historique de chaque compte n'était pas
 * praticable : cette liste est le point d'entrée de leur traitement.
 */
@RequiredArgsConstructor
public class GetEcartsEnAttenteUseCase {

    private final ClotureCaisseRepository clotureCaisseRepository;

    @Transactional(readOnly = true)
    public List<ClotureCaisse> executer() {
        return clotureCaisseRepository.findEcartsEnAttente();
    }
}
