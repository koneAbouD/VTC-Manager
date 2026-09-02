package com.tmk.vtcmanager.application.usecases.reaffectation;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.reaffectation.ApercuReaffectation;
import com.tmk.vtcmanager.application.domain.reaffectation.CandidatReaffectation;
import com.tmk.vtcmanager.application.domain.reaffectation.ImpactsReaffectation;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.services.IndisponibiliteSubstitutionService;
import com.tmk.vtcmanager.application.services.ReaffectationChauffeurService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Ce que l'écran de réaffectation demande à l'ouverture : qui peut reprendre la
 * créance, et ce que le déplacement entraînera.
 *
 * <p>Tout est tranché ici, rien ne l'est côté client. C'est ce qui permet à la
 * feuille de montrer le conflit <b>avant</b> le choix — un chauffeur déjà pris
 * ailleurs apparaît grisé, avec sa raison — au lieu de laisser l'utilisateur
 * choisir puis se faire refuser.
 */
@RequiredArgsConstructor
public class GetApercuReaffectationUseCase {

    private final LigneRecetteRepository ligneRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;
    private final IndisponibiliteSubstitutionService indisponibiliteSubstitutionService;
    private final ReaffectationChauffeurService reaffectationService;

    @Transactional(readOnly = true)
    public ApercuReaffectation pourRecette(Long ligneId) {
        LigneRecette ligne = ligneRecetteRepository.findById(ligneId)
                .orElseThrow(() -> new LigneRecetteNotFoundException(ligneId));

        var cible = ReaffectationChauffeurService.Cible.de(ligne);
        List<CandidatReaffectation> candidats = candidats(cible, ligne.getVehiculeId(),
                ligne.getDateRecette(), ligne.getChauffeurId());

        // Le montant de la créance, c'est ce qui est attendu ; une recette à
        // montant réel n'en a pas, et ce qui a été versé en tient lieu.
        BigDecimal creance = ligne.getMontantAttendu() != null
                ? ligne.getMontantAttendu() : montantEncaisse(ligne);
        List<LignePenalite> penalites = reaffectationService.penalitesQuiSuivent(ligneId);

        return new ApercuReaffectation(candidats, new ImpactsReaffectation(
                creance,
                versementsVivants(ligne),
                montantEncaisse(ligne),
                penalites.size(),
                penalites.stream()
                        .map(p -> p.getMontant() != null ? p.getMontant() : BigDecimal.ZERO)
                        .reduce(BigDecimal.ZERO, BigDecimal::add)));
    }

    @Transactional(readOnly = true)
    public ApercuReaffectation pourCotisation(Long ligneId) {
        LigneCotisation ligne = ligneCotisationRepository.findById(ligneId)
                .orElseThrow(() -> new LigneCotisationNotFoundException(ligneId));

        var cible = ReaffectationChauffeurService.Cible.de(ligne);
        List<CandidatReaffectation> candidats = candidats(cible, ligne.getVehiculeId(),
                ligne.getDateCotisation(), ligne.getChauffeurId());

        // Rien ne s'adosse à une cotisation : aucune pénalité à emmener.
        return new ApercuReaffectation(candidats, new ImpactsReaffectation(
                ligne.getMontantDu(),
                versementsVivants(ligne),
                ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO,
                0,
                BigDecimal.ZERO));
    }

    /**
     * Tous les chauffeurs, sans filtre de statut.
     *
     * <p>Une créance de mars se réaffecte à qui la devait en mars : ce qui
     * compte, c'est qui conduisait ce jour-là, pas qui est en poste aujourd'hui.
     * Écarter un chauffeur suspendu ou en congé depuis rendrait précisément
     * incorrigibles les erreurs les plus anciennes.
     */
    private List<CandidatReaffectation> candidats(ReaffectationChauffeurService.Cible cible,
                                                  Long vehiculeId, LocalDate date, Long actuelId) {
        List<Chauffeur> chauffeurs = chauffeurRepository.findAll();
        return reaffectationService.evaluerCandidats(
                cible, chauffeurs, auProgramme(vehiculeId, date), actuelId);
    }

    /**
     * Les conducteurs attendus au volant de ce véhicule ce jour-là, remplacements
     * appliqués : c'est ce que la génération aurait retenu. Sert à ranger la
     * liste, jamais à filtrer — un chauffeur hors programme reste choisissable,
     * et c'est même le cas le plus courant d'une correction.
     */
    private Set<Long> auProgramme(Long vehiculeId, LocalDate date) {
        return programmeTravailRepository.findByVehiculeId(vehiculeId)
                .filter(programme -> programme.travailleCeJour(date))
                .<Set<Long>>map(programme -> new HashSet<>(indisponibiliteSubstitutionService
                        .appliquer(programme.chauffeursActifs(date), date)))
                .orElse(Set.of());
    }

    private int versementsVivants(LigneRecette ligne) {
        return ligne.getEncaissements() == null ? 0
                : (int) ligne.getEncaissements().stream()
                        .filter(e -> e.getAnnuleLe() == null).count();
    }

    private int versementsVivants(LigneCotisation ligne) {
        return ligne.getEncaissements() == null ? 0
                : (int) ligne.getEncaissements().stream()
                        .filter(e -> e.getAnnuleLe() == null).count();
    }

    private BigDecimal montantEncaisse(LigneRecette ligne) {
        return ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO;
    }
}
