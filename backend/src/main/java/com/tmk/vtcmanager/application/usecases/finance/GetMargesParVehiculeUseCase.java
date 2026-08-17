package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CompteResultat.BaseComptable;
import com.tmk.vtcmanager.application.domain.finance.MargeVehicule;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.YearMonth;
import java.util.List;

@RequiredArgsConstructor
public class GetMargesParVehiculeUseCase {

    private final FinanceReportingRepository reportingRepository;

    /**
     * Détail par véhicule de la cascade servie par {@link GetCompteResultatUseCase} :
     * la base demandée gouverne les deux lectures, sans quoi la liste contredirait
     * le compte de résultat affiché au-dessus d'elle.
     */
    @Transactional(readOnly = true)
    public List<MargeVehicule> executer(int annee, int mois, BaseComptable base) {
        YearMonth periode = YearMonth.of(annee, mois);
        return reportingRepository.margesParVehicule(
                periode.atDay(1), periode.atEndOfMonth(), base);
    }
}
