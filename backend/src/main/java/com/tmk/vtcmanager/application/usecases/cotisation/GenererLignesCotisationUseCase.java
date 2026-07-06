package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.CotisationRecette;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.JourFerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.services.IndisponibiliteSubstitutionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
public class GenererLignesCotisationUseCase {

    private final ProgrammeTravailRepository programmeTravailRepository;
    private final ConfigurationRecetteRepository configurationRecetteRepository;
    private final LigneCotisationRepository ligneCotisationRepository;
    private final IndisponibiliteSubstitutionService indisponibiliteSubstitutionService;
    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private final JourFerieRepository jourFerieRepository;

    @Transactional
    public List<LigneCotisation> executer(LocalDate date) {
        List<ProgrammeTravail> programmes = programmeTravailRepository.findAllWithChauffeurs();
        List<LigneCotisation> generees = new ArrayList<>();
        boolean estFerie = jourFerieRepository.existsByDate(date);

        for (ProgrammeTravail programme : programmes) {
            if (programme.getChauffeurs() == null || programme.getChauffeurs().isEmpty()) continue;
            if (!programme.travailleCeJour(date)) continue;
            // Véhicule immobilisé (indisponibilité) ce jour → aucune cotisation due.
            if (indisponibiliteVehiculeRepository.isImmobiliseAt(programme.getVehiculeId(), date)) continue;
            // Jour de salaire ou jour férié pris en compte : le chauffeur roule pour son
            // propre compte → aucune cotisation due.
            if (programme.estJourSalaire(date) || programme.suspendPourFerie(estFerie)) {
                purgerCotisationsDuJour(programme.getVehiculeId(), date);
                continue;
            }

            ConfigurationRecette config = configurationRecetteRepository
                    .findByVehiculeId(programme.getVehiculeId())
                    .orElse(null);
            if (config == null || config.getCotisations() == null || config.getCotisations().isEmpty()) continue;

            // Conducteurs du jour avec substitution des titulaires indisponibles.
            List<Long> chauffeursActifs = indisponibiliteSubstitutionService
                    .appliquer(programme.chauffeursActifs(date), date);

            for (Long chauffeurId : chauffeursActifs) {
                List<LigneCotisation> existantes = new ArrayList<>(
                        ligneCotisationRepository.findByVehiculeIdAndDateCotisation(
                                programme.getVehiculeId(), date).stream()
                                .filter(l -> chauffeurId.equals(l.getChauffeurId()))
                                .toList());

                // Noms des cotisations actives (normalisés)
                Set<String> nomsActifs = config.getCotisations().stream()
                        .map(c -> LigneCotisation.normaliserNom(c.getNom()))
                        .collect(Collectors.toSet());

                // Nettoyer les lignes obsolètes
                nettoyerObsoletes(existantes, nomsActifs);

                for (CotisationRecette cotisation : config.getCotisations()) {
                    String nomNormalise = LigneCotisation.normaliserNom(cotisation.getNom());

                    LigneCotisation ligne = existantes.stream()
                            .filter(l -> nomNormalise.equals(LigneCotisation.normaliserNom(l.getNomCotisation())))
                            .findFirst()
                            .map(l -> mettreAJour(l, cotisation.getMontant()))
                            .orElseGet(() -> creer(programme.getVehiculeId(), chauffeurId, date,
                                    cotisation.getNom(), cotisation.getMontant()));

                    LigneCotisation sauvee = ligneCotisationRepository.save(ligne);
                    if (ligne.getId() == null) existantes.add(sauvee);
                    generees.add(sauvee);
                }
            }
        }

        return generees;
    }

    /**
     * Supprime les lignes de cotisation EN_ATTENTE sans encaissement d'un véhicule
     * pour une date devenue jour de salaire (aucune cotisation n'y est due).
     * Idempotent : rend possible la correction d'un jour déjà généré.
     */
    private void purgerCotisationsDuJour(Long vehiculeId, LocalDate date) {
        ligneCotisationRepository.findByVehiculeIdAndDateCotisation(vehiculeId, date).stream()
                .filter(l -> l.getStatut() == StatutLigneCotisation.EN_ATTENTE
                        && (l.getMontantEncaisse() == null
                                || l.getMontantEncaisse().compareTo(BigDecimal.ZERO) == 0))
                .forEach(l -> {
                    ligneCotisationRepository.deleteById(l.getId());
                    log.info("Cotisation jour de salaire purgée : id={}, véhicule={}, date={}",
                            l.getId(), vehiculeId, date);
                });
    }

    private void nettoyerObsoletes(List<LigneCotisation> existantes, Set<String> nomsActifs) {
        List<LigneCotisation> aSupprimer = existantes.stream()
                .filter(l -> !nomsActifs.contains(LigneCotisation.normaliserNom(l.getNomCotisation()))
                        && l.getStatut() == StatutLigneCotisation.EN_ATTENTE
                        && (l.getMontantEncaisse() == null
                                || l.getMontantEncaisse().compareTo(BigDecimal.ZERO) == 0))
                .toList();

        aSupprimer.forEach(l -> {
            ligneCotisationRepository.deleteById(l.getId());
            log.info("Ligne cotisation obsolète supprimée : id={}, nom={}", l.getId(), l.getNomCotisation());
        });
        existantes.removeAll(aSupprimer);
    }

    private LigneCotisation creer(Long vehiculeId, Long chauffeurId, LocalDate date,
                                   String nomCotisation, BigDecimal montant) {
        return LigneCotisation.builder()
                .vehiculeId(vehiculeId)
                .chauffeurId(chauffeurId)
                .dateCotisation(date)
                .nomCotisation(LigneCotisation.normaliserNom(nomCotisation))
                .montantDu(montant)
                .montantEncaisse(BigDecimal.ZERO)
                .statut(StatutLigneCotisation.EN_ATTENTE)
                .encaissements(new ArrayList<>())
                .build();
    }

    private LigneCotisation mettreAJour(LigneCotisation existante, BigDecimal montant) {
        if (existante.getStatut() != StatutLigneCotisation.ANNULEE) {
            existante.setMontantDu(montant);
        }
        return existante;
    }

}
