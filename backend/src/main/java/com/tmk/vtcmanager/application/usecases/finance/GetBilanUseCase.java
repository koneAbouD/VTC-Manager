package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.BilanGestion;
import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.CreanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.FacturePartenaireRepository;
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
    private final GetProvisionCreancesUseCase getProvisionCreancesUseCase;
    private final FacturePartenaireRepository facturePartenaireRepository;

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

        // Les créances entrent à l'actif pour leur valeur probable de
        // recouvrement, pas pour leur montant facial.
        BigDecimal provision = getProvisionCreancesUseCase.executer().getProvisionTotale();
        BigDecimal creancesNettes = creances.subtract(provision);

        BigDecimal immobilisations = reportingRepository.immobilisationsNettes(aujourdHui);
        BigDecimal detteEtat = creanceRepository.getMontantAReverserEtat();
        BigDecimal dettesFournisseurs = facturePartenaireRepository.detteALaDate(aujourdHui);

        BigDecimal totalActif = tresorerie.add(creancesNettes).add(immobilisations);

        return BilanGestion.builder()
                .date(aujourdHui)
                .tresorerie(tresorerie)
                .creancesChauffeurs(creances)
                .provisionCreances(provision)
                .creancesNettes(creancesNettes)
                .immobilisationsNettes(immobilisations)
                .totalActif(totalActif)
                .detteEtatContraventions(detteEtat)
                .dettesFournisseurs(dettesFournisseurs)
                .situationNette(totalActif.subtract(detteEtat).subtract(dettesFournisseurs))
                .build();
    }
}
