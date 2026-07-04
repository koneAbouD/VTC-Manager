package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@RequiredArgsConstructor
public class GetMontantAReverserEtatUseCase {

    private final CreanceRepository creanceRepository;

    @Transactional(readOnly = true)
    public BigDecimal executer() {
        return creanceRepository.getMontantAReverserEtat();
    }
}
