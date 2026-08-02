package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Annulation d'une contravention saisie à tort.
 *
 * <p>Elle n'est jamais effacée : tant qu'elle était due, elle a figuré parmi
 * les créances sur le chauffeur, et les états déjà arrêtés doivent continuer de
 * la montrer. L'annulation l'horodate, la motive et la signe ; c'est cette date
 * — et non le statut — qui la retire des lectures postérieures.
 *
 * <p>Deux situations lui sont fermées, parce qu'un mouvement d'argent les a
 * déjà dépassées : une contravention encaissée auprès du chauffeur (il faut
 * d'abord extourner l'encaissement, qui a sa propre écriture) et une
 * contravention reversée à l'État (l'argent est parti, seul un dégrèvement
 * obtenu de l'administration peut le ramener).
 */
@RequiredArgsConstructor
public class AnnulerContraventionUseCase {

    private final ContraventionRepository contraventionRepository;
    private final AuteurCourant auteurCourant;

    @Transactional
    public Contravention execute(Long id, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException(
                    "Le motif d'annulation est obligatoire : il justifie le retrait de la créance.");
        }

        Contravention contravention = contraventionRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Contravention", id));

        if (contravention.estAnnulee()) {
            throw new IllegalStateException("Cette contravention est déjà annulée.");
        }
        if (contravention.getDateReversement() != null) {
            throw new IllegalStateException("Cette contravention a été reversée à l'État : "
                    + "elle ne s'annule plus, seul un dégrèvement de l'administration "
                    + "peut la remettre en cause.");
        }
        if (contravention.aDesVersements()) {
            throw new IllegalStateException("Le chauffeur a déjà versé "
                    + contravention.getMontantPaye().toPlainString()
                    + " sur cette contravention : extournez d'abord l'encaissement.");
        }

        contravention.annuler(motif, auteurCourant.nom());
        return contraventionRepository.save(contravention);
    }
}
