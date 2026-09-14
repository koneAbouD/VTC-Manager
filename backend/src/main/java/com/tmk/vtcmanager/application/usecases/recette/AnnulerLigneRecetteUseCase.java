package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;

@Slf4j
@RequiredArgsConstructor
public class AnnulerLigneRecetteUseCase {

    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;

    /** Annulation de la seule recette. */
    @Transactional
    public LigneRecette executer(Long id, String motif) {
        return executer(id, motif, false);
    }

    /**
     * Annule la recette et, si {@code annulerCotisationsLiees}, les cotisations
     * de la même journée de travail.
     *
     * <p>Recette et cotisations naissent du même fait — cette voiture, ce
     * chauffeur, ce jour — et meurent le plus souvent ensemble : une journée qui
     * n'a pas eu lieu ne doit rien laisser derrière elle. La cascade reste
     * pourtant un choix explicite de l'utilisateur : une recette annulée pour
     * erreur de montant laisse, elle, les cotisations dues.
     *
     * <p>Une cotisation déjà servie n'est pas annulée pour autant : elle touche
     * la trésorerie et exige d'abord la contre-passation de ses versements. Elle
     * est écartée sans faire échouer l'annulation de la recette — l'écran
     * l'annonce avant de proposer la case.
     */
    @Transactional
    public LigneRecette executer(Long id, String motif, boolean annulerCotisationsLiees) {
        LigneRecette ligne = ligneRecetteRepository.findById(id)
                .orElseThrow(() -> new LigneRecetteNotFoundException(id));

        if (ligne.getStatut() == StatutLigneRecette.ANNULEE) {
            return ligne;
        }
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif d'annulation est obligatoire.");
        }
        // Une ligne déjà encaissée (même partiellement) touche la trésorerie :
        // il faut d'abord annuler les encaissements liés avant de pouvoir annuler
        // la ligne (garantit la cohérence des finances).
        if (ligne.aDesVersements()) {
            throw new IllegalStateException(
                    "Impossible d'annuler une ligne ayant déjà des versements. "
                            + "Annulez d'abord les encaissements liés.");
        }

        String motifNettoye = motif.trim();
        ligne.annuler(motifNettoye);
        LigneRecette annulee = ligneRecetteRepository.save(ligne);

        if (annulerCotisationsLiees) {
            annulerCotisationsDeLaJournee(ligne, motifNettoye);
        }
        return annulee;
    }

    private void annulerCotisationsDeLaJournee(LigneRecette recette, String motif) {
        for (LigneCotisation cotisation : cotisationsAnnulables(recette)) {
            cotisation.annuler(motif);
            ligneCotisationRepository.save(cotisation);
            log.info("Cotisation {} ({}) annulée avec la recette {} du {}",
                    cotisation.getId(), cotisation.getNomCotisation(),
                    recette.getId(), recette.getDateRecette());
        }
    }

    /**
     * Les cotisations que la recette entraîne dans sa chute : même véhicule,
     * même chauffeur, même jour, encore dues et sans versement qui tienne.
     */
    private List<LigneCotisation> cotisationsAnnulables(LigneRecette recette) {
        return ligneCotisationRepository
                .findByVehiculeIdAndDateCotisation(recette.getVehiculeId(), recette.getDateRecette())
                .stream()
                .filter(c -> Objects.equals(c.getChauffeurId(), recette.getChauffeurId()))
                .filter(c -> c.getStatut() != StatutLigneCotisation.ANNULEE)
                .filter(c -> c.getStatut() != StatutLigneCotisation.RESTITUEE)
                .filter(c -> !c.aDesVersements())
                .toList();
    }
}
