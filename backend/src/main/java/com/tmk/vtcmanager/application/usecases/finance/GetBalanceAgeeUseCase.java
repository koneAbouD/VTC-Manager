package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class GetBalanceAgeeUseCase {

    private final CreanceRepository creanceRepository;

    @Transactional(readOnly = true)
    public List<CreanceChauffeur> executer() {
        return creanceRepository.getBalanceAgee();
    }
}
