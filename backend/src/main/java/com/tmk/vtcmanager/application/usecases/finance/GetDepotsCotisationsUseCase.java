package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Dépôts de cotisations détenus aujourd'hui pour le compte des chauffeurs :
 * encaissés, pas encore rendus par un arrêté. Même lecture que le passif du
 * bilan — la trésorerie les contient, mais ils ne sont pas à l'entreprise.
 * Montant brut de compensation : une part servira peut-être à éteindre des
 * créances, mais tant que l'arrêté n'est pas passé, tout reste dû.
 */
@RequiredArgsConstructor
public class GetDepotsCotisationsUseCase {

    private final CompteCourantRepository compteCourantRepository;

    @Transactional(readOnly = true)
    public BigDecimal executer() {
        BigDecimal depots = compteCourantRepository.fondsCotisationsALaDate(LocalDate.now());
        return depots == null ? BigDecimal.ZERO : depots.max(BigDecimal.ZERO);
    }
}
