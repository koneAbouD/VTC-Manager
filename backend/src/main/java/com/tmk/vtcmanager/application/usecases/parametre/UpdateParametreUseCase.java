package com.tmk.vtcmanager.application.usecases.parametre;

import com.tmk.vtcmanager.application.domain.parametre.ParametreCles;
import com.tmk.vtcmanager.application.domain.parametre.ParametreGeneral;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ParametreGeneralRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class UpdateParametreUseCase {

    private final ParametreGeneralRepository repository;

    public ParametreGeneral executer(String cle, String valeur) {
        ParametreGeneral parametre = repository.findByCle(cle)
                .orElseThrow(() -> new ResourceNotFoundException("Paramètre introuvable : " + cle));
        valider(cle, valeur);
        parametre.setValeur(valeur.trim());
        return repository.save(parametre);
    }

    /** Contrôles de cohérence propres à chaque paramètre connu. */
    private void valider(String cle, String valeur) {
        if (ParametreCles.DUREE_AMORTISSEMENT_MOIS.equals(cle)) {
            final int mois;
            try {
                mois = Integer.parseInt(valeur.trim());
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException(
                        "La durée d'amortissement doit être un nombre entier de mois.");
            }
            if (mois < 1) {
                throw new IllegalArgumentException(
                        "La durée d'amortissement doit être d'au moins 1 mois.");
            }
        }
    }
}
