package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.BilanGestion;
import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.FinanceReportingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

@RequiredArgsConstructor
public class GetBilanUseCase {

    private final CompteTresorerieRepository compteTresorerieRepository;
    private final CreanceRepository creanceRepository;
    private final FinanceReportingRepository reportingRepository;

    /**
     * Bilan de gestion à aujourd'hui : chaque poste est un calcul dérivé
     * des stocks courants (soldes, créances ouvertes, VNC des véhicules,
     * contraventions non reversées). La situation nette est obtenue par
     * différence — équilibre par construction.
     */
    @Transactional(readOnly = true)
    public BilanGestion executer() {
        LocalDate aujourdHui = LocalDate.now();

        BigDecimal tresorerie = compteTresorerieRepository.findAllAvecSoldes(true).stream()
                .map(CompteAvecSolde::getSolde)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal creances = creanceRepository.getBalanceAgee().stream()
                .map(CreanceChauffeur::getTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal immobilisations = reportingRepository.immobilisationsNettes(aujourdHui);
        BigDecimal detteEtat = creanceRepository.getMontantAReverserEtat();

        BigDecimal totalActif = tresorerie.add(creances).add(immobilisations);

        return BilanGestion.builder()
                .date(aujourdHui)
                .tresorerie(tresorerie)
                .creancesChauffeurs(creances)
                .immobilisationsNettes(immobilisations)
                .totalActif(totalActif)
                .detteEtatContraventions(detteEtat)
                .situationNette(totalActif.subtract(detteEtat))
                .build();
    }
}
