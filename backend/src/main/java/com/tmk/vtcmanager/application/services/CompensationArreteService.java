package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Dit, versement par versement, lequel est une compensation d'arrêté de compte
 * et non un argent reçu au guichet.
 *
 * <p>L'arrêté éteint une créance avec le dépôt de cotisations du chauffeur : il
 * enregistre pour cela un encaissement et son écriture, sans caisse. Sans ce
 * marquage, la fiche l'afficherait comme un versement en espèces. On le
 * reconnaît par son écriture, rattachée à une ligne de l'arrêté : c'est ce lien,
 * et non un libellé ou une référence, qui fait foi.
 */
@RequiredArgsConstructor
public class CompensationArreteService {

    private final ArreteCompteRepository arreteCompteRepository;

    public void marquer(LigneRecette ligne) {
        List<Encaissement> versements = ligne.getEncaissements();
        if (versements == null || versements.isEmpty()) return;
        Map<Long, String> references = arreteCompteRepository.referencesArreteParOperationCompensation(
                versements.stream().map(Encaissement::getOperationFinanciereId)
                        .filter(Objects::nonNull).toList());
        versements.forEach(e -> e.setArreteCompensation(reference(references, e.getOperationFinanciereId())));
    }

    public void marquer(LignePenalite ligne) {
        List<EncaissementPenalite> versements = ligne.getEncaissements();
        if (versements == null || versements.isEmpty()) return;
        Map<Long, String> references = arreteCompteRepository.referencesArreteParOperationCompensation(
                versements.stream().map(EncaissementPenalite::getOperationFinanciereId)
                        .filter(Objects::nonNull).toList());
        versements.forEach(e -> e.setArreteCompensation(reference(references, e.getOperationFinanciereId())));
    }

    /** Un versement hérité n'a pas d'écriture : rien à chercher, et pas de clé nulle. */
    private static String reference(Map<Long, String> references, Long operationId) {
        return operationId == null ? null : references.get(operationId);
    }
}
