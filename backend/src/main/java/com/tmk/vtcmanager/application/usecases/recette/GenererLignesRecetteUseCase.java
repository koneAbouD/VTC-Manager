package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ModeAlternance;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
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

@Slf4j
@RequiredArgsConstructor
public class GenererLignesRecetteUseCase {

    private final ProgrammeTravailRepository programmeTravailRepository;
    private final ConfigurationRecetteRepository configurationRecetteRepository;
    private final LigneRecetteRepository ligneRecetteRepository;

    @Transactional
    public List<LigneRecette> executer(LocalDate date) {
        List<ProgrammeTravail> programmes = programmeTravailRepository.findAllWithChauffeurs();
        List<LigneRecette> generees = new ArrayList<>();

        for (ProgrammeTravail programme : programmes) {
            if (programme.getChauffeurs() == null || programme.getChauffeurs().isEmpty()) {
                continue;
            }

            ConfigurationRecette config = configurationRecetteRepository
                    .findByVehiculeId(programme.getVehiculeId())
                    .orElse(null);

            if (config == null) {
                log.warn("Aucune ConfigurationRecette pour le véhicule {} — lignes ignorées", programme.getVehiculeId());
                continue;
            }

            if (!travailleCeJour(programme, date)) {
                log.debug("Véhicule {} ne travaille pas le {} — lignes ignorées",
                        programme.getVehiculeId(), date.getDayOfWeek());
                continue;
            }

            BigDecimal montantAttendu = resolveMontantAttendu(config);
            List<Long> chauffeursActifs = determinerChauffeursActifs(programme, date);

            // Liste mutable : alimentée avec les lignes existantes + celles créées en cours de boucle
            List<LigneRecette> lignesExistantes = new ArrayList<>(
                    ligneRecetteRepository.findByVehiculeIdAndDateRecette(programme.getVehiculeId(), date));

            // Supprimer les lignes EN_ATTENTE sans encaissement pour des chauffeurs qui ne travaillent plus ce jour
            nettoyerLignesObsoletes(lignesExistantes, chauffeursActifs);

            for (Long chauffeurId : chauffeursActifs) {
                LigneRecette ligne = resoudreOuCreerLigne(
                        lignesExistantes, programme.getVehiculeId(), chauffeurId, date, montantAttendu);
                LigneRecette sauvee = ligneRecetteRepository.save(ligne);
                // Mettre à jour la liste pour que les prochains chauffeurs voient la ligne déjà traitée
                if (ligne.getId() == null) {
                    lignesExistantes.add(sauvee);
                }
                generees.add(sauvee);
                log.info("Ligne {}: véhicule={}, chauffeur={}, date={}, montantAttendu={}",
                        ligne.getId() != null ? "mise à jour" : "générée",
                        programme.getVehiculeId(), chauffeurId, date, montantAttendu);
            }
        }

        return generees;
    }

    /**
     * Stratégie de résolution :
     * 1. Si une ligne existe déjà pour ce chauffeur → mise à jour du montant attendu.
     * 2. Si une ligne EN_ATTENTE existe pour un autre chauffeur (alternance changée)
     *    → mise à jour du chauffeur et du montant attendu.
     * 3. Sinon → création d'une nouvelle ligne.
     * Les lignes ANNULÉES ne sont jamais modifiées.
     */
    /**
     * Stratégie de résolution :
     * 1. Ligne déjà affectée à ce chauffeur (non annulée) → mise à jour du montant attendu.
     * 2. Ligne EN_ATTENTE d'un autre chauffeur sans encaissement (alternance reconfigurée)
     *    → réaffectation du chauffeur et mise à jour du montant attendu.
     * 3. Aucune ligne réutilisable → création.
     */
    private LigneRecette resoudreOuCreerLigne(
            List<LigneRecette> existantes, Long vehiculeId, Long chauffeurId,
            LocalDate date, BigDecimal montantAttendu) {

        // 1. Même chauffeur, ligne non annulée
        var memeChauffeur = existantes.stream()
                .filter(l -> chauffeurId.equals(l.getChauffeurId())
                        && l.getStatut() != StatutLigneRecette.ANNULEE)
                .findFirst();
        if (memeChauffeur.isPresent()) {
            memeChauffeur.get().setMontantAttendu(montantAttendu);
            return memeChauffeur.get();
        }

        // 2. Autre chauffeur, EN_ATTENTE, aucun encaissement → réaffecter
        var autreEnAttente = existantes.stream()
                .filter(l -> !chauffeurId.equals(l.getChauffeurId())
                        && l.getStatut() == StatutLigneRecette.EN_ATTENTE
                        && (l.getMontantEncaisse() == null
                                || l.getMontantEncaisse().compareTo(BigDecimal.ZERO) == 0))
                .findFirst();
        if (autreEnAttente.isPresent()) {
            LigneRecette ligne = autreEnAttente.get();
            ligne.setChauffeurId(chauffeurId);
            ligne.setMontantAttendu(montantAttendu);
            return ligne;
        }

        // 3. Aucune ligne réutilisable → créer
        return LigneRecette.builder()
                .vehiculeId(vehiculeId)
                .chauffeurId(chauffeurId)
                .dateRecette(date)
                .montantAttendu(montantAttendu)
                .montantEncaisse(BigDecimal.ZERO)
                .statut(StatutLigneRecette.EN_ATTENTE)
                .encaissements(new ArrayList<>())
                .build();
    }

    /**
     * Supprime les lignes EN_ATTENTE sans encaissement appartenant à des chauffeurs
     * qui ne sont plus actifs ce jour (ex: alternance reconfigurée, chauffeur changé).
     * Retire ces lignes de la liste pour qu'elles ne soient pas réutilisées.
     */
    private void nettoyerLignesObsoletes(List<LigneRecette> existantes, List<Long> chauffeursActifs) {
        List<LigneRecette> aSupprimer = existantes.stream()
                .filter(l -> !chauffeursActifs.contains(l.getChauffeurId())
                        && l.getStatut() == StatutLigneRecette.EN_ATTENTE
                        && (l.getMontantEncaisse() == null
                                || l.getMontantEncaisse().compareTo(BigDecimal.ZERO) == 0))
                .toList();

        for (LigneRecette l : aSupprimer) {
            ligneRecetteRepository.deleteById(l.getId());
            log.info("Ligne obsolète supprimée : id={}, véhicule={}, chauffeur={} (inactif)",
                    l.getId(), l.getVehiculeId(), l.getChauffeurId());
        }
        existantes.removeAll(aSupprimer);
    }

    private boolean travailleCeJour(ProgrammeTravail programme, LocalDate date) {
        if (programme.getJoursTravailSemaine() == null || programme.getJoursTravailSemaine().isEmpty()) {
            return true; // aucune restriction → travaille tous les jours
        }
        return programme.getJoursTravailSemaine().contains(JourSemaine.from(date.getDayOfWeek()));
    }

    private BigDecimal resolveMontantAttendu(ConfigurationRecette config) {
        if (config.getTypeRecette() == TypeRecetteConfiguration.MONTANT_FIXE) {
            return config.getMontantObjectifParChauffeur();
        }
        return null; // MONTANT_REEL : pas de montant fixe attendu
    }

    private List<Long> determinerChauffeursActifs(ProgrammeTravail programme, LocalDate date) {
        List<ProgrammeChauffeur> chauffeurs = programme.getChauffeurs();

        if (programme.getNombreChauffeursAutorises() == null || programme.getNombreChauffeursAutorises() == 1) {
            return chauffeurs.stream()
                    .filter(pc -> pc.getChauffeurId() != null)
                    .map(ProgrammeChauffeur::getChauffeurId)
                    .toList();
        }

        // 2 chauffeurs : vérifier si c'est un jour de travail commun
        if (programme.getJoursAlternanceSemaine() != null
                && !programme.getJoursAlternanceSemaine().isEmpty()) {
            if (programme.getJoursAlternanceSemaine().contains(JourSemaine.from(date.getDayOfWeek()))) {
                return chauffeurs.stream()
                        .filter(pc -> pc.getChauffeurId() != null)
                        .map(ProgrammeChauffeur::getChauffeurId)
                        .toList();
            }
        }

        if (programme.getModeAlternance() == ModeAlternance.AUTOMATIQUE
                && programme.getDateDebutAlternance() != null
                && programme.getJoursAlternance() != null) {
            return List.of(determinerChauffeurAlternanceAuto(programme, date));
        }

        // Mode MANUELLE : génère pour tous les chauffeurs assignés
        return chauffeurs.stream()
                .filter(pc -> pc.getChauffeurId() != null)
                .map(ProgrammeChauffeur::getChauffeurId)
                .toList();
    }

    private Long determinerChauffeurAlternanceAuto(ProgrammeTravail programme, LocalDate date) {
        long joursEcoules = ChronoUnit.DAYS.between(programme.getDateDebutAlternance(), date);
        long periode = joursEcoules / programme.getJoursAlternance();
        boolean chauffeurUn = (periode % 2) == 0;

        return programme.getChauffeurs().stream()
                .filter(pc -> pc.getChauffeurId() != null)
                .filter(pc -> chauffeurUn
                        ? pc.getOrdreAlternance() != null && pc.getOrdreAlternance() == 1
                        : pc.getOrdreAlternance() != null && pc.getOrdreAlternance() == 2)
                .map(ProgrammeChauffeur::getChauffeurId)
                .findFirst()
                .orElseGet(() -> programme.getChauffeurs().stream()
                        .filter(pc -> pc.getChauffeurId() != null)
                        .map(ProgrammeChauffeur::getChauffeurId)
                        .findFirst()
                        .orElseThrow());
    }
}
