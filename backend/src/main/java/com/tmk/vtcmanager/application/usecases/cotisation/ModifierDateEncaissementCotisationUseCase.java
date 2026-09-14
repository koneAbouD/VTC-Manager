package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.EncaissementFuturGuard;
import com.tmk.vtcmanager.application.services.ModificationDateEncaissementService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Objects;

/**
 * Corrige le jour où un versement de cotisation est réputé encaissé.
 *
 * <p>Voir {@link com.tmk.vtcmanager.application.usecases.recette.ModifierDateEncaissementRecetteUseCase}
 * pour le principe : aucun montant ne bouge, seule la date se déplace, sur le
 * versement et sur l'écriture qu'il a produite.
 *
 * <p>Une cotisation encaissée est un dépôt détenu pour le chauffeur, et sa date
 * dit à partir de quand : le fonds à date et le décompte d'un arrêté de compte
 * s'en déduisent. C'est pourquoi la correction se ferme dès qu'un arrêté a rendu
 * tout ou partie de ce dépôt.
 */
@RequiredArgsConstructor
public class ModifierDateEncaissementCotisationUseCase {

    private final LigneCotisationRepository ligneCotisationRepository;
    private final EncaissementCotisationRepository encaissementCotisationRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final ModificationDateEncaissementService modificationDateService;
    private final EncaissementFuturGuard encaissementFuturGuard;

    @Transactional
    public LigneCotisation executer(Long ligneCotisationId, Long encaissementId,
                                    LocalDate nouvelleDate) {
        LigneCotisation ligne = ligneCotisationRepository.findById(ligneCotisationId)
                .orElseThrow(() -> new LigneCotisationNotFoundException(ligneCotisationId));

        EncaissementCotisation encaissement = encaissementCotisationRepository
                .findById(encaissementId)
                .orElseThrow(() -> ResourceNotFoundException.of("Encaissement", encaissementId));
        if (!Objects.equals(encaissement.getLigneCotisationId(), ligneCotisationId)) {
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
        encaissementCotisationRepository.save(encaissement);

        if (operation != null) {
            operation.setDateOperation(nouvelleDate);
            operationFinanciereRepository.save(operation);
            // Un versement se lit à un seul jour. Déplacer l'une de ses
            // écritures sans sa sœur ferait mentir la pièce de caisse : elles
            // redeviennent deux encaissements, chacun à sa date.
            if (operation.getVersementId() != null) {
                operationFinanciereRepository.detacherVersement(operation.getVersementId());
            }
        }

        return ligneCotisationRepository.findById(ligneCotisationId)
                .orElseThrow(() -> new LigneCotisationNotFoundException(ligneCotisationId));
    }

    /** Voir le use case recette : une écriture extournée ne se déplace plus. */
    private OperationFinanciere operation(EncaissementCotisation encaissement) {
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
