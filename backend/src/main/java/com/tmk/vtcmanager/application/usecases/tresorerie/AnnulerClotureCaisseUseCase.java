package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.usecases.operationFinanciere.AnnulerOperationFinanciereUseCase;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Annulation d'un relevé de caisse erroné.
 *
 * <p>Un comptage saisi à la mauvaise date enfermait l'utilisateur : la série des
 * comptages devant rester chronologique, plus aucun relevé antérieur ne pouvait
 * être enregistré — et la clôture du mois concerné devenait impossible à
 * satisfaire, faute de comptage tombant dans le mois.
 *
 * <p>Le procès-verbal n'est jamais supprimé : il reste au dossier, marqué de son
 * motif et de son auteur. Il cesse simplement de faire foi, et les contrôles qui
 * s'appuyaient sur lui — unicité de la journée, chronologie, exigence de clôture
 * — l'ignorent désormais.
 *
 * <p>Deux situations restent fermées, parce que les défaire demanderait plus
 * qu'une marque : une période comptable déjà close, et un écart dont
 * l'imputation a déjà été tranchée. Dans ce dernier cas, il faut d'abord
 * extourner les écritures d'imputation.
 */
@RequiredArgsConstructor
public class AnnulerClotureCaisseUseCase {

    private final ClotureCaisseRepository clotureCaisseRepository;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final AnnulerOperationFinanciereUseCase annulerOperationUseCase;
    private final AuteurCourant auteurCourant;

    @Transactional
    public ClotureCaisse executer(Long clotureId, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException(
                    "Le motif d'annulation est obligatoire : il justifie le retrait du relevé.");
        }

        ClotureCaisse cloture = clotureCaisseRepository.findById(clotureId)
                .orElseThrow(() -> ResourceNotFoundException.of("Relevé de caisse", clotureId));

        if (cloture.estAnnule()) {
            throw new IllegalStateException("Ce relevé est déjà annulé.");
        }
        // Le mois qu'il atteste est publié : le retirer changerait un état déjà
        // servi.
        periodeClotureeGuard.verifier(cloture.getDateCloture());
        if (cloture.ecartImpute()) {
            throw new IllegalStateException("L'écart de ce relevé a déjà été imputé : "
                    + "extournez d'abord les écritures d'imputation.");
        }

        // Le relevé cesse de faire foi avant toute autre écriture : c'est ce qui
        // rouvre la journée, sans quoi la contre-passation ci-dessous se
        // heurterait au verrou de la caisse comptée.
        cloture.annuler(motif, auteurCourant.nom());
        ClotureCaisse annulee = clotureCaisseRepository.save(cloture);

        // L'ajustement qui avait réaligné le solde sur le comptage n'a plus lieu
        // d'être : il est contre-passé, jamais effacé.
        if (annulee.getOperationId() != null) {
            annulerOperationUseCase.execute(annulee.getOperationId(),
                    "Annulation du relevé de caisse du " + annulee.getDateCloture()
                            + " — " + motif);
        }

        return annulee;
    }
}
