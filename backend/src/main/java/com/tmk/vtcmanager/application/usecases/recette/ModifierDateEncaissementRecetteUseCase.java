package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.EncaissementRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.EncaissementFuturGuard;
import com.tmk.vtcmanager.application.services.ModificationDateEncaissementService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Objects;

/**
 * Corrige le jour où un versement de recette est réputé encaissé.
 *
 * <p>Aucun montant ne bouge : la recette reste due du même montant, le
 * versement reste du même montant, le statut de la ligne ne change pas. Ce qui
 * se déplace, c'est la date — sur l'encaissement <b>et</b> sur l'écriture qu'il
 * a produite au journal, les deux devant rester d'accord. De là suivent, sans
 * autre écriture, le solde de trésorerie à date, le compte de résultat du mois,
 * et l'ancienneté de la créance dans la balance âgée du chauffeur, qui se
 * lisent tous sur ces deux dates.
 *
 * <p>Ce qui l'interdit est rassemblé dans
 * {@link ModificationDateEncaissementService} : la même règle refuse ici et se
 * lit sur la fiche.
 */
@RequiredArgsConstructor
public class ModifierDateEncaissementRecetteUseCase {

    private final LigneRecetteRepository ligneRecetteRepository;
    private final EncaissementRepository encaissementRepository;
    private final OperationFinanciereRepository operationFinanciereRepository;
    private final ModificationDateEncaissementService modificationDateService;
    private final EncaissementFuturGuard encaissementFuturGuard;

    @Transactional
    public LigneRecette executer(Long ligneRecetteId, Long encaissementId, LocalDate nouvelleDate) {
        LigneRecette ligne = ligneRecetteRepository.findById(ligneRecetteId)
                .orElseThrow(() -> new LigneRecetteNotFoundException(ligneRecetteId));

        Encaissement encaissement = encaissementRepository.findById(encaissementId)
                .orElseThrow(() -> ResourceNotFoundException.of("Encaissement", encaissementId));
        if (!Objects.equals(encaissement.getLigneRecetteId(), ligneRecetteId)) {
            throw ResourceNotFoundException.of("Encaissement", encaissementId);
        }

        if (Objects.equals(encaissement.getDateEncaissement(), nouvelleDate)) {
            return ligne; // Rien à corriger : pas d'écriture pour rien.
        }

        // L'avenir d'abord, comme à la saisie : un encaissement constate de
        // l'argent déjà compté, le postdater fausserait tous les soldes à date.
        encaissementFuturGuard.verifier(nouvelleDate);
        modificationDateService.verifierLigne(ligne);

        OperationFinanciere operation = operation(encaissement);
        Long compteId = operation != null ? operation.getCompteTresorerieId() : null;
        modificationDateService.verifierVersement(encaissement.getDateEncaissement(), compteId,
                encaissement.getAnnuleLe() != null);
        modificationDateService.verifierNouvelleDate(nouvelleDate, compteId);

        encaissement.setDateEncaissement(nouvelleDate);
        encaissementRepository.save(encaissement);

        // L'écriture suit le versement : sans elle, le journal et la créance
        // diraient deux jours différents pour le même argent. La date de
        // référence, elle, reste celle de la recette — c'est la période due,
        // pas la transaction.
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

        return ligneRecetteRepository.findById(ligneRecetteId)
                .orElseThrow(() -> new LigneRecetteNotFoundException(ligneRecetteId));
    }

    /**
     * L'écriture liée, refusée si elle a été contre-passée : le couple
     * extourne/origine se lit à sa date, et déplacer l'une sans l'autre le
     * romprait. Un versement sans écriture (donnée héritée) reste corrigeable.
     */
    private OperationFinanciere operation(Encaissement encaissement) {
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
