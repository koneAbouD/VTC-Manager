package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Annule une ligne de cotisation encore ouverte, motif à l'appui.
 *
 * <p>Deux cas sont admis :
 * <ul>
 *   <li>une ligne <b>en attente</b>, sans aucun versement ;</li>
 *   <li>une ligne <b>partiellement encaissée</b> dont tout le versé a déjà été
 *       rendu par un arrêté de compte. On abandonne alors le reste impayé : le
 *       compte de la période est arrêté, cette dette ne sera plus réclamée.</li>
 * </ul>
 *
 * <p>Une ligne qui détient encore du fonds est refusée : ANNULEE la sortirait
 * du compte courant, et le dépôt du chauffeur disparaîtrait sans avoir été
 * rendu. Il faut d'abord l'arrêter (ou extourner les versements).
 */
@RequiredArgsConstructor
public class AnnulerLigneCotisationUseCase {

    private final LigneCotisationRepository ligneCotisationRepository;

    @Transactional
    public LigneCotisation executer(Long id, String motif) {
        LigneCotisation ligne = ligneCotisationRepository.findById(id)
                .orElseThrow(() -> new LigneCotisationNotFoundException(id));
        if (ligne.getStatut() == StatutLigneCotisation.ANNULEE) {
            return ligne;
        }
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif d'annulation est obligatoire.");
        }
        if (!ligne.estActive()) {
            throw new IllegalStateException(
                    "Seule une cotisation en attente ou partiellement encaissée peut être annulée.");
        }
        if (ligne.aDesVersements() && ligne.fondRestituable().signum() > 0) {
            throw new IllegalStateException(
                    "Cette cotisation détient encore " + ligne.fondRestituable().toPlainString()
                            + " F versés et non restitués. Arrêtez d'abord le compte du chauffeur"
                            + " (ou annulez les encaissements liés) avant d'abandonner le reste.");
        }
        ligne.annuler(motif.trim());
        return ligneCotisationRepository.save(ligne);
    }
}
