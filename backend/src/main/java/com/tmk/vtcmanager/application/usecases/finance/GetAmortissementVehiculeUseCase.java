package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.AmortissementVehicule;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Optional;

@RequiredArgsConstructor
public class GetAmortissementVehiculeUseCase {

    private final FinanceReportingRepository reportingRepository;

    /**
     * Plan d'amortissement d'un véhicule à aujourd'hui, pour sa fiche : durée
     * effective, point de départ et valeur nette comptable. C'est la même
     * lecture que celle qui alimente l'actif du bilan, à la journée près.
     */
    @Transactional(readOnly = true)
    public Optional<AmortissementVehicule> executer(Long vehiculeId) {
        return reportingRepository.amortissementVehicule(vehiculeId, LocalDate.now());
    }
}
