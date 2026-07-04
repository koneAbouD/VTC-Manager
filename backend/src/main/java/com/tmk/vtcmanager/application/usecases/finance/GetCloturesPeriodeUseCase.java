package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class GetCloturesPeriodeUseCase {

    private final CloturePeriodeRepository cloturePeriodeRepository;

    @Transactional(readOnly = true)
    public List<CloturePeriode> executer() {
        return cloturePeriodeRepository.findAllOrderByPeriodeDesc();
    }
}
