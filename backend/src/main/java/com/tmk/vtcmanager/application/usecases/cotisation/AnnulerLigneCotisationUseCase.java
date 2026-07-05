package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

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
        if (ligne.aDesVersements()) {
            throw new IllegalStateException(
                    "Impossible d'annuler une ligne ayant déjà des versements. "
                            + "Annulez d'abord les encaissements liés.");
        }
        ligne.annuler(motif.trim());
        return ligneCotisationRepository.save(ligne);
    }
}
