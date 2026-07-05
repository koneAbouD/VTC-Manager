package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ModeAlternance;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Slf4j
@RequiredArgsConstructor
public class GenererLignesPenaliteUseCase {

    private final ProgrammeTravailRepository programmeTravailRepository;
    private final ConditionTravailRepository conditionTravailRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final LignePenaliteRepository lignePenaliteRepository;
    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;

    @Transactional
    public List<LignePenalite> executerPourRecettesNonVersees(LocalDate dateFaute) {
        List<ProgrammeTravail> programmes = programmeTravailRepository.findAllWithChauffeurs();
        List<LignePenalite> generees = new ArrayList<>();

        for (ProgrammeTravail programme : programmes) {
            if (programme.getChauffeurs() == null || programme.getChauffeurs().isEmpty()) continue;
            // Véhicule immobilisé (indisponibilité) ce jour → aucune recette due donc aucune pénalité.
            if (indisponibiliteVehiculeRepository.isImmobiliseAt(programme.getVehiculeId(), dateFaute)) continue;

            var conditionOpt = conditionTravailRepository.findByVehiculeId(programme.getVehiculeId());
            if (conditionOpt.isEmpty()) continue;

            ConditionTravail condition = conditionOpt.get();
            if (condition.getPenalites() == null) continue;

            Optional<PenaliteTemplate> templateOpt = condition.getPenalites().stream()
                    .filter(p -> TypePenalite.RECETTE_NON_VERSEE.name().equals(p.getTypePenalite()))
                    .findFirst();
            if (templateOpt.isEmpty()) continue;

            PenaliteTemplate template = templateOpt.get();

            List<Long> chauffeursActifs = determinerChauffeursActifs(programme, dateFaute);

            for (Long chauffeurId : chauffeursActifs) {
                Optional<LigneRecette> ligneRecetteOpt = ligneRecetteRepository
                        .findByVehiculeIdAndChauffeurIdAndDateRecette(
                                programme.getVehiculeId(), chauffeurId, dateFaute);

                if (ligneRecetteOpt.isEmpty()) continue;

                LigneRecette ligneRecette = ligneRecetteOpt.get();
                if (ligneRecette.getStatut() != StatutLigneRecette.EN_ATTENTE
                        && ligneRecette.getStatut() != StatutLigneRecette.PARTIELLEMENT_ENCAISSE) {
                    continue;
                }

                if (lignePenaliteRepository.existsDejaGeneree(
                        programme.getVehiculeId(), chauffeurId,
                        TypePenalite.RECETTE_NON_VERSEE, dateFaute)) {
                    continue;
                }

                LignePenalite ligne = creer(
                        programme.getVehiculeId(), chauffeurId,
                        template, dateFaute, ligneRecette.getId());

                generees.add(lignePenaliteRepository.save(ligne));
                log.info("Pénalité RECETTE_NON_VERSEE générée : vehicule={}, chauffeur={}, date={}",
                        programme.getVehiculeId(), chauffeurId, dateFaute);
            }
        }

        return generees;
    }

    private LignePenalite creer(Long vehiculeId, Long chauffeurId,
                                 PenaliteTemplate template, LocalDate dateFaute,
                                 Long ligneRecetteId) {
        TypeSanction typeSanction = TypeSanction.valueOf(template.getTypeSanction());
        return LignePenalite.builder()
                .vehiculeId(vehiculeId)
                .chauffeurId(chauffeurId)
                .penaliteTemplateId(template.getId())
                .typePenalite(TypePenalite.RECETTE_NON_VERSEE)
                .typeSanction(typeSanction)
                .montant(template.getMontant() != null ? BigDecimal.valueOf(template.getMontant()) : BigDecimal.ZERO)
                .montantEncaisse(BigDecimal.ZERO)
                .dureeSanctionSecondes(template.getDureeSanctionSecondes())
                .dureeImmobilisationMinutes(template.getDureeImmobilisationMinutes())
                .dateGeneration(LocalDate.now())
                .dateFaute(dateFaute)
                .ligneRecetteId(ligneRecetteId)
                .statut(StatutLignePenalite.EN_ATTENTE)
                .encaissements(new ArrayList<>())
                .build();
    }

    private List<Long> determinerChauffeursActifs(ProgrammeTravail programme, LocalDate date) {
        List<ProgrammeChauffeur> chauffeurs = programme.getChauffeurs();

        if (programme.getNombreChauffeursAutorises() == null
                || programme.getNombreChauffeursAutorises() == 1) {
            return chauffeurs.stream()
                    .filter(pc -> pc.getChauffeurId() != null)
                    .map(ProgrammeChauffeur::getChauffeurId).toList();
        }

        if (programme.getJoursAlternanceSemaine() != null
                && !programme.getJoursAlternanceSemaine().isEmpty()
                && programme.getJoursAlternanceSemaine().contains(JourSemaine.from(date.getDayOfWeek()))) {
            return chauffeurs.stream()
                    .filter(pc -> pc.getChauffeurId() != null)
                    .map(ProgrammeChauffeur::getChauffeurId).toList();
        }

        if (programme.getModeAlternance() == ModeAlternance.AUTOMATIQUE
                && programme.getDateDebutAlternance() != null
                && programme.getJoursAlternance() != null) {
            long joursEcoules = ChronoUnit.DAYS.between(programme.getDateDebutAlternance(), date);
            long periode = joursEcoules / programme.getJoursAlternance();
            boolean chauffeurUn = (periode % 2) == 0;
            return List.of(chauffeurs.stream()
                    .filter(pc -> pc.getChauffeurId() != null)
                    .filter(pc -> chauffeurUn
                            ? pc.getOrdreAlternance() != null && pc.getOrdreAlternance() == 1
                            : pc.getOrdreAlternance() != null && pc.getOrdreAlternance() == 2)
                    .map(ProgrammeChauffeur::getChauffeurId)
                    .findFirst()
                    .orElseGet(() -> chauffeurs.stream()
                            .filter(pc -> pc.getChauffeurId() != null)
                            .map(ProgrammeChauffeur::getChauffeurId)
                            .findFirst().orElseThrow()));
        }

        return chauffeurs.stream()
                .filter(pc -> pc.getChauffeurId() != null)
                .map(ProgrammeChauffeur::getChauffeurId).toList();
    }
}
