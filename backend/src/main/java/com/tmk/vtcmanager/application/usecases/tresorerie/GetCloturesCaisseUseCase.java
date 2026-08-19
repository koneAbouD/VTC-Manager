package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class GetCloturesCaisseUseCase {

    private final ClotureCaisseRepository clotureCaisseRepository;

    /**
     * Relevés en vigueur du compte : ceux qui font foi, et sur lesquels les
     * verrous s'appuient.
     */
    @Transactional(readOnly = true)
    public List<ClotureCaisse> executer(Long compteId) {
        return executer(compteId, false);
    }

    /**
     * @param inclureAnnules vrai pour l'historique — les relevés retirés y
     *                       figurent, marqués : c'est ce qui rend lisible la
     *                       succession des comptages d'une même journée, et ce
     *                       qui explique pourquoi une date reste fermée.
     */
    @Transactional(readOnly = true)
    public List<ClotureCaisse> executer(Long compteId, boolean inclureAnnules) {
        return inclureAnnules
                ? clotureCaisseRepository.findHistoriqueByCompteId(compteId)
                : clotureCaisseRepository.findByCompteIdOrderByDateDesc(compteId);
    }
}
