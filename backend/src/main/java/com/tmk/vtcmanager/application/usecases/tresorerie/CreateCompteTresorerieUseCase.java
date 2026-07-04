package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.exception.CompteTresorerieCodeExistantException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@RequiredArgsConstructor
public class CreateCompteTresorerieUseCase {

    private final CompteTresorerieRepository compteTresorerieRepository;

    @Transactional
    public CompteTresorerie executer(CompteTresorerie compte) {
        if (compteTresorerieRepository.existsByCode(compte.getCode())) {
            throw new CompteTresorerieCodeExistantException(compte.getCode());
        }
        if (compte.getSoldeInitial() == null) {
            compte.setSoldeInitial(BigDecimal.ZERO);
        }
        compte.setActif(true);

        // Premier compte de son type : il devient le compte par défaut,
        // sinon la résolution par mode de paiement n'aurait pas de cible.
        if (compteTresorerieRepository.countActifsByType(compte.getType()) == 0) {
            compte.setParDefaut(true);
        }
        return compteTresorerieRepository.save(compte);
    }
}
