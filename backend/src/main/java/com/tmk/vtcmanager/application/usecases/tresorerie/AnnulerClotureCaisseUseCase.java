package com.tmk.vtcmanager.application.usecases.tresorerie;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import com.tmk.vtcmanager.application.services.PeriodeClotureeGuard;
import com.tmk.vtcmanager.application.usecases.operationFinanciere.AnnulerOperationFinanciereUseCase;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

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
 * qu'une marque : une période comptable déjà close, et un compte recompté
 * depuis, dont le relevé le plus récent doit être retiré en premier.
 *
 * <p>Un écart déjà tranché, lui, ne ferme plus la porte : le retrait défait
 * l'imputation avant de retirer le relevé. L'exiger de l'utilisateur l'enfermait
 * — l'action n'existait nulle part, et une extourne passée à la main n'aurait
 * de toute façon pas remis l'écart en attente.
 */
@RequiredArgsConstructor
public class AnnulerClotureCaisseUseCase {

    private final ClotureCaisseRepository clotureCaisseRepository;
    private final PeriodeClotureeGuard periodeClotureeGuard;
    private final AnnulerOperationFinanciereUseCase annulerOperationUseCase;
    private final AnnulerImputationEcartUseCase annulerImputationEcartUseCase;
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
        // Les relevés se défont dans l'ordre inverse où ils ont été posés. Un
        // comptage postérieur a été fait sur un solde théorique où l'ajustement
        // de celui-ci était déjà compris : retirer l'ancien d'abord rendrait le
        // récent faux sans que personne ne l'ait touché.
        LocalDate dateReleve = cloture.getDateCloture();
        clotureCaisseRepository.findDerniereDateCloture(cloture.getCompteId())
                .ifPresent(derniere -> {
                    if (derniere.isAfter(dateReleve)) {
                        throw new IllegalStateException("Ce compte a été recompté depuis, le "
                                + derniere + " : retirez d'abord le relevé du " + derniere
                                + ", puis celui-ci.");
                    }
                });

        // L'arbitrage rendu sur l'écart tombe le premier : il portait sur un
        // écart que le retrait fait disparaître. Ses deux écritures sont
        // contre-passées à la date du relevé, et l'écart repasse en attente —
        // état que l'annulation ci-dessous efface aussitôt, personne n'ayant
        // plus rien à trancher.
        if (cloture.ecartImpute()) {
            cloture = annulerImputationEcartUseCase.defaire(cloture,
                    "Retrait du relevé de caisse du " + cloture.getDateCloture() + " — " + motif);
        }

        // Le relevé cesse de faire foi avant toute autre écriture : c'est ce qui
        // rouvre la journée, sans quoi la contre-passation ci-dessous se
        // heurterait au verrou de la caisse comptée.
        cloture.annuler(motif, auteurCourant.nom());
        ClotureCaisse annulee = clotureCaisseRepository.save(cloture);

        // L'ajustement qui avait réaligné le solde sur le comptage n'a plus lieu
        // d'être : il est contre-passé, jamais effacé. L'extourne porte la date
        // du relevé, pas celle du jour : c'est la journée comptée qu'il fallait
        // remettre dans son état d'avant. Extournée au jour de l'annulation,
        // elle laisserait le solde théorique de cette journée-là faussé du
        // montant de l'écart, et le recomptage buterait sur un écart fantôme.
        if (annulee.getOperationId() != null) {
            annulerOperationUseCase.execute(annulee.getOperationId(),
                    "Annulation du relevé de caisse du " + annulee.getDateCloture()
                            + " — " + motif,
                    annulee.getDateCloture());
        }

        return annulee;
    }
}
