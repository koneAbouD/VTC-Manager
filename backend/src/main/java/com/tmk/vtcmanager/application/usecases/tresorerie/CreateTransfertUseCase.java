package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.TransfertTresorerie;
import com.tmk.vtcmanager.application.exception.CompteTresorerieNotFoundException;
import com.tmk.vtcmanager.application.exception.TransfertInvalideException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.TransfertTresorerieRepository;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;

@RequiredArgsConstructor
public class CreateTransfertUseCase {

    private final TransfertTresorerieRepository transfertRepository;
    private final CompteTresorerieRepository compteTresorerieRepository;
    private final PeriodeClotureeGuard periodeClotureeGuard;

    @Transactional
    public TransfertTresorerie executer(TransfertTresorerie transfert) {
        if (transfert.getMontant() == null
                || transfert.getMontant().compareTo(BigDecimal.ZERO) <= 0) {
            throw new TransfertInvalideException("Le montant du transfert doit être positif");
        }
        if (transfert.getCompteSourceId() == null || transfert.getCompteDestinationId() == null
                || transfert.getCompteSourceId().equals(transfert.getCompteDestinationId())) {
            throw new TransfertInvalideException("Les comptes source et destination doivent être distincts");
        }
        verifierCompte(transfert.getCompteSourceId());
        verifierCompte(transfert.getCompteDestinationId());

        if (transfert.getDateTransfert() == null) {
            transfert.setDateTransfert(LocalDate.now());
        }
        periodeClotureeGuard.verifier(transfert.getDateTransfert());

        return transfertRepository.save(transfert);
    }

    private void verifierCompte(Long id) {
        compteTresorerieRepository.findById(id)
                .orElseThrow(() -> new CompteTresorerieNotFoundException(id));
    }
}
