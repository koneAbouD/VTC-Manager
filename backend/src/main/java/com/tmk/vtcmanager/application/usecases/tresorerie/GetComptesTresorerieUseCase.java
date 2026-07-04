package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class GetComptesTresorerieUseCase {

    private final CompteTresorerieRepository compteTresorerieRepository;

    @Transactional(readOnly = true)
    public List<CompteAvecSolde> executer(boolean actifsSeulement) {
        return compteTresorerieRepository.findAllAvecSoldes(actifsSeulement);
    }
}
