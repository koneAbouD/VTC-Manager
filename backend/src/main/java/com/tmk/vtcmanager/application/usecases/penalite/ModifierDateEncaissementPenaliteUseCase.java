package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementPenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.EncaissementFuturGuard;
import com.tmk.vtcmanager.application.services.ModificationDateEncaissementService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Objects;

/**
 * Corrige le jour où un versement d'amende est réputé encaissé.
 *
 * <p>Voir {@link com.tmk.vtcmanager.application.usecases.recette.ModifierDateEncaissementRecetteUseCase}
 * pour le principe : aucun montant ne bouge, seule la date se déplace, sur le
 * versement et sur l'écriture qu'il a produite. La date de référence reste celle
 * de la faute — c'est le jour sanctionné, pas celui du règlement.
 *
 * <p>Seules les amendes ont des versements ; les autres sanctions — buzzer,
 * avertissement, immobilisation — n'encaissent rien et n'ont donc rien à
 * redater.
 */
@RequiredArgsConstructor
public class ModifierDateEncaissementPenaliteUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;
    private final EncaissementPenaliteRepository encaissementPenaliteRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final ModificationDateEncaissementService modificationDateService;
    private final EncaissementFuturGuard encaissementFuturGuard;

    @Transactional
    public LignePenalite executer(Long lignePenaliteId, Long encaissementId,
                                  LocalDate nouvelleDate) {
        LignePenalite ligne = lignePenaliteRepository.findById(lignePenaliteId)
                .orElseThrow(() -> new LignePenaliteNotFoundException(lignePenaliteId));

        EncaissementPenalite encaissement = encaissementPenaliteRepository.findById(encaissementId)
                .orElseThrow(() -> ResourceNotFoundException.of("Encaissement", encaissementId));
        if (!Objects.equals(encaissement.getLignePenaliteId(), lignePenaliteId)) {
            throw ResourceNotFoundException.of("Encaissement", encaissementId);
        }

        if (Objects.equals(encaissement.getDateEncaissement(), nouvelleDate)) {
            return ligne; // Rien à corriger : pas d'écriture pour rien.
        }

        encaissementFuturGuard.verifier(nouvelleDate);
        modificationDateService.verifierLigne(ligne);

        OperationFinanciere operation = operation(encaissement);
        Long compteId = operation != null ? operation.getCompteTresorerieId() : null;
        modificationDateService.verifierVersement(encaissement.getDateEncaissement(), compteId,
                encaissement.getAnnuleLe() != null);
        modificationDateService.verifierNouvelleDate(nouvelleDate, compteId);

        encaissement.setDateEncaissement(nouvelleDate);
        encaissementPenaliteRepository.save(encaissement);

        if (operation != null) {
            operation.setDateOperation(nouvelleDate);
            operationFinanciereRepository.save(operation);
        }

        return lignePenaliteRepository.findById(lignePenaliteId)
                .orElseThrow(() -> new LignePenaliteNotFoundException(lignePenaliteId));
    }

    /** Voir le use case recette : une écriture extournée ne se déplace plus. */
    private OperationFinanciere operation(EncaissementPenalite encaissement) {
        if (encaissement.getOperationFinanciereId() == null) return null;
        OperationFinanciere operation = operationFinanciereRepository
                .findById(encaissement.getOperationFinanciereId())
                .orElse(null);
        if (operation != null && !operation.estAnnulable()) {
            throw new EcritureFigeeException("L'écriture de cet encaissement a été extournée ou"
                    + " annulée : sa date ne se corrige plus. Ressaisissez un encaissement à la"
                    + " bonne date.");
        }
        return operation;
    }
}
