package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.LigneCreance;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class GetCreancesVehiculeUseCase {

    private final CreanceRepository creanceRepository;

    @Transactional(readOnly = true)
    public List<LigneCreance> executer(Long vehiculeId) {
        return creanceRepository.getLignesCreanceParVehicule(vehiculeId);
    }
}
