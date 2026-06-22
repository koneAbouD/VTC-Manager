package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.CotisationRecette;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ModeAlternance;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
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

    @Transactional
    public List<LigneCotisation> executer(LocalDate date) {
        List<ProgrammeTravail> programmes = programmeTravailRepository.findAllWithChauffeurs();
        List<LigneCotisation> generees = new ArrayList<>();

        for (ProgrammeTravail programme : programmes) {
            if (programme.getChauffeurs() == null || programme.getChauffeurs().isEmpty()) continue;
            if (!travailleCeJour(programme, date)) continue;

            ConfigurationRecette config = configurationRecetteRepository
                    .findByVehiculeId(programme.getVehiculeId())
                    .orElse(null);
            if (config == null || config.getCotisations() == null || config.getCotisations().isEmpty()) continue;

            List<Long> chauffeursActifs = determinerChauffeursActifs(programme, date);

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

    private boolean travailleCeJour(ProgrammeTravail programme, LocalDate date) {
        if (programme.getJoursTravailSemaine() == null || programme.getJoursTravailSemaine().isEmpty()) {
            return true;
        }
        return programme.getJoursTravailSemaine().contains(JourSemaine.from(date.getDayOfWeek()));
    }

    private List<Long> determinerChauffeursActifs(ProgrammeTravail programme, LocalDate date) {
        List<ProgrammeChauffeur> chauffeurs = programme.getChauffeurs();

        if (programme.getNombreChauffeursAutorises() == null || programme.getNombreChauffeursAutorises() == 1) {
            return chauffeurs.stream().filter(pc -> pc.getChauffeurId() != null)
                    .map(ProgrammeChauffeur::getChauffeurId).toList();
        }

        if (programme.getJoursAlternanceSemaine() != null && !programme.getJoursAlternanceSemaine().isEmpty()) {
            if (programme.getJoursAlternanceSemaine().contains(JourSemaine.from(date.getDayOfWeek()))) {
                return chauffeurs.stream().filter(pc -> pc.getChauffeurId() != null)
                        .map(ProgrammeChauffeur::getChauffeurId).toList();
            }
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

        return chauffeurs.stream().filter(pc -> pc.getChauffeurId() != null)
                .map(ProgrammeChauffeur::getChauffeurId).toList();
    }
}
