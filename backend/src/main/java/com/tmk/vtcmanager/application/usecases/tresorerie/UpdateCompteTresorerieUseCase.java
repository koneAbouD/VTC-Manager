package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.exception.CompteTresorerieNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class UpdateCompteTresorerieUseCase {

    private final CompteTresorerieRepository compteTresorerieRepository;

    /**
     * Met à jour libellé, opérateur, solde initial (mise en service /
     * correction de comptage), compte par défaut et activation. Le code et
     * le type sont immuables : les opérations passées y sont rattachées.
     */
    @Transactional
    public CompteTresorerie executer(Long id, CompteTresorerie modifications) {
        CompteTresorerie compte = compteTresorerieRepository.findById(id)
                .orElseThrow(() -> new CompteTresorerieNotFoundException(id));

        if (modifications.getLibelle() != null) {
            compte.setLibelle(modifications.getLibelle());
        }
        if (modifications.getOperateur() != null) {
            compte.setOperateur(modifications.getOperateur());
        }
        if (modifications.getSoldeInitial() != null) {
            compte.setSoldeInitial(modifications.getSoldeInitial());
        }

        if (modifications.isParDefaut() && !compte.isParDefaut()) {
            // Bascule du compte par défaut : l'ancien du même type perd le flag
            // (index unique partiel sur (type) WHERE par_defaut).
            compteTresorerieRepository.findParDefautByType(compte.getType())
                    .filter(ancien -> !ancien.getId().equals(id))
                    .ifPresent(ancien -> {
                        ancien.setParDefaut(false);
                        compteTresorerieRepository.save(ancien);
                    });
            compte.setParDefaut(true);
        }

        compte.setActif(modifications.isActif());
        return compteTresorerieRepository.save(compte);
    }
}
