package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class GetCloturesCaisseUseCase {

    private final ClotureCaisseRepository clotureCaisseRepository;

    @Transactional(readOnly = true)
    public List<ClotureCaisse> executer(Long compteId) {
        return clotureCaisseRepository.findByCompteIdOrderByDateDesc(compteId);
    }
}
