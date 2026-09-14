package com.tmk.vtcmanager.application.usecases.versement;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.versement.Versement;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import com.tmk.vtcmanager.application.services.LectureImputationService;
import lombok.RequiredArgsConstructor;

import java.util.List;
import java.util.UUID;

/**
 * Lit une pièce de caisse : ses écritures, et pour chacune la créance qu'elle
 * solde avec ce qu'il y reste à devoir.
 *
 * <p>Le reste dû ne se lit pas sur l'écriture — elle ne connaît pas la ligne
 * qui l'a produite. {@link LectureImputationService} le retrouve par
 * l'encaissement : c'est ce qui permet au reçu d'un versement de dire ce que le
 * chauffeur doit encore.
 */
@RequiredArgsConstructor
public class GetVersementUseCase {

    private final OperationFinanciereRepository operationFinanciereRepository;
    private final LectureImputationService lectureImputationService;

    public Versement executer(UUID versementId) {
        List<OperationFinanciere> ecritures = operationFinanciereRepository.findByVersementId(versementId);
        if (ecritures.isEmpty()) {
            throw new ResourceNotFoundException("Versement introuvable : " + versementId);
        }

        // Les écritures d'un versement partagent billet, jour et chauffeur —
        // c'est l'invariant que tiennent les corrections. La première suffit.
        OperationFinanciere tete = ecritures.get(0);
        Chauffeur chauffeur = tete.getChauffeur();
        Vehicule vehicule = tete.getVehicule();

        return new Versement(
                versementId,
                tete.getDateOperation(),
                tete.getModePaiement(),
                chauffeur == null ? null : chauffeur.getId(),
                nomComplet(chauffeur),
                chauffeur == null ? null : chauffeur.getTelephone(),
                vehicule == null ? null : vehicule.getId(),
                vehicule == null ? null : vehicule.getImmatriculation(),
                ecritures.stream().map(lectureImputationService::lire).toList());
    }

    private static String nomComplet(Chauffeur chauffeur) {
        if (chauffeur == null) return null;
        String prenom = chauffeur.getPrenom() != null ? chauffeur.getPrenom() : "";
        String nom = chauffeur.getNom() != null ? chauffeur.getNom() : "";
        String complet = (prenom + " " + nom).trim();
        return complet.isEmpty() ? null : complet;
    }
}
