package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

/**
 * Recalcule et persiste le statut d'un chauffeur à partir de ses signaux métier
 * (indisponibilité active aujourd'hui → EN_CONGE, sinon ACTIF). Respecte le
 * statut manuel verrouillant (INACTIF, SUSPENDU). Ne sauvegarde que si le statut
 * change effectivement.
 */
@RequiredArgsConstructor
public class RecomputeChauffeurStatusUseCase {

    private final ChauffeurRepository chauffeurRepository;
    private final IndisponibiliteRepository indisponibiliteRepository;

    @Transactional
    public void execute(Long chauffeurId) {
        if (chauffeurId == null) return;

        Chauffeur chauffeur = chauffeurRepository.findById(chauffeurId)
                .orElseThrow(() -> new ChauffeurNotFoundException(chauffeurId));

        LocalDate aujourdhui = LocalDate.now();
        boolean enConge = indisponibiliteRepository.isEnCongeAt(chauffeurId, aujourdhui);
        // « En service » si affecté à un véhicule OU remplaçant actif aujourd'hui
        // (substitution d'un titulaire indisponible via le modèle overlay).
        boolean affecte = chauffeur.getVehicule() != null
                || indisponibiliteRepository.isRemplacantActifAt(chauffeurId, aujourdhui);

        ChauffeurStatus avant = chauffeur.getStatut();
        chauffeur.appliquerStatutCalcule(enConge, affecte);

        if (chauffeur.getStatut() != avant) {
            chauffeurRepository.save(chauffeur);
        }
    }
}
