package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.CompteTresorerieNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import lombok.RequiredArgsConstructor;

/**
 * Résout le compte de trésorerie d'une opération : compte explicite s'il est
 * fourni, sinon compte par défaut du type dérivé du mode de paiement.
 * Retourne null en dernier recours (aucun compte configuré) : l'opération
 * reste valide, simplement non rattachée — comme les opérations legacy.
 */
@RequiredArgsConstructor
public class CompteTresorerieResolver {

    private final CompteTresorerieRepository compteTresorerieRepository;

    public Long resoudre(Long compteTresorerieId, ModePaiement modePaiement) {
        if (compteTresorerieId != null) {
            return compteTresorerieRepository.findById(compteTresorerieId)
                    .map(CompteTresorerie::getId)
                    .orElseThrow(() -> new CompteTresorerieNotFoundException(compteTresorerieId));
        }
        if (modePaiement == null) {
            return null;
        }
        return compteTresorerieRepository
                .findParDefautByType(TypeCompteTresorerie.pourModePaiement(modePaiement))
                .map(CompteTresorerie::getId)
                .orElse(null);
    }
}
