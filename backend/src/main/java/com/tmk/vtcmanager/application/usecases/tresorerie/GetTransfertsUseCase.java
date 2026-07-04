package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.TransfertTresorerie;
import com.tmk.vtcmanager.application.ports.persistence.TransfertTresorerieRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class GetTransfertsUseCase {

    private final TransfertTresorerieRepository transfertRepository;

    @Transactional(readOnly = true)
    public List<TransfertTresorerie> executer() {
        return transfertRepository.findAllOrderByDateDesc();
    }
}
