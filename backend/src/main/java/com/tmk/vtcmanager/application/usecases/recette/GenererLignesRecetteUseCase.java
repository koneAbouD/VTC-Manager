package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.JourFerieRepository;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.services.IndisponibiliteSubstitutionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@RequiredArgsConstructor
public class GenererLignesRecetteUseCase {

    private final ProgrammeTravailRepository programmeTravailRepository;
    private final ConfigurationRecetteRepository configurationRecetteRepository;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final IndisponibiliteSubstitutionService indisponibiliteSubstitutionService;
    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private final JourFerieRepository jourFerieRepository;

    @Transactional
    public List<LigneRecette> executer(LocalDate date) {
        List<ProgrammeTravail> programmes = programmeTravailRepository.findAllWithChauffeurs();
        List<LigneRecette> generees = new ArrayList<>();
        boolean estFerie = jourFerieRepository.existsByDate(date);

        for (ProgrammeTravail programme : programmes) {
            if (programme.getChauffeurs() == null || programme.getChauffeurs().isEmpty()) {
                continue;
            }

            // Véhicule immobilisé (indisponibilité) ce jour → aucune recette due.
            if (indisponibiliteVehiculeRepository.isImmobiliseAt(programme.getVehiculeId(), date)) {
                log.debug("Véhicule {} immobilisé (indisponibilité) le {} — recettes ignorées",
                        programme.getVehiculeId(), date);
                continue;
            }

            ConfigurationRecette config = configurationRecetteRepository
                    .findByVehiculeId(programme.getVehiculeId())
                    .orElse(null);

            if (config == null) {
                log.warn("Aucune ConfigurationRecette pour le véhicule {} — lignes ignorées", programme.getVehiculeId());
                continue;
            }

            if (!programme.travailleCeJour(date)) {
                log.debug("Véhicule {} ne travaille pas le {} — lignes ignorées",
                        programme.getVehiculeId(), date.getDayOfWeek());
                continue;
            }

            // Conducteurs planifiés du jour, avec substitution des titulaires
            // indisponibles par leur remplaçant (uniquement pour cette date).
            List<Long> chauffeursActifs = indisponibiliteSubstitutionService
                    .appliquer(programme.chauffeursActifs(date), date);

            // Liste mutable : alimentée avec les lignes existantes + celles créées en cours de boucle
            List<LigneRecette> lignesExistantes = new ArrayList<>(
                    ligneRecetteRepository.findByVehiculeIdAndDateRecette(programme.getVehiculeId(), date));

            // Programme modifié rétroactivement (ex : inversion de l'alternance) : si un
            // chauffeur qui ne roule plus ce jour a déjà encaissé, l'obligation du jour a
            // été honorée par le chauffeur qui a réellement conduit. On ne régénère rien
            // pour ce véhicule+date afin d'éviter un doublon de recette.
            if (dejaHonoreParChauffeurRetire(lignesExistantes, chauffeursActifs)) {
                log.warn("Véhicule {} le {} : recette déjà encaissée par un chauffeur retiré du programme "
                        + "— génération ignorée (évite un doublon)", programme.getVehiculeId(), date);
                continue;
            }

            // Jour de salaire ou jour férié pris en compte : le chauffeur roule pour son
            // propre compte. La recette due vaut le montant spécial (souvent 0) :
            // nul ou 0 → aucune ligne.
            boolean jourSalaire = programme.estJourSalaire(date);
            boolean jourFerie = programme.suspendPourFerie(estFerie);
            BigDecimal montantAttendu;
            if (jourSalaire || jourFerie) {
                // Le jour de salaire prime si les deux coïncident.
                BigDecimal montantSpecial = jourSalaire
                        ? config.getMontantJourSalaire()
                        : config.getMontantJourFerie();
                if (montantSpecial == null || montantSpecial.signum() == 0) {
                    // Aucune recette due : purger les lignes EN_ATTENTE sans encaissement.
                    nettoyerLignesObsoletes(lignesExistantes, List.of());
                    log.debug("Véhicule {} le {} : jour {} — aucune recette due",
                            programme.getVehiculeId(), date, jourSalaire ? "de salaire" : "férié");
                    continue;
                }
                montantAttendu = montantSpecial;
            } else {
                montantAttendu = resolveMontantAttendu(config);
            }

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

    /**
     * Vrai si une ligne appartenant à un chauffeur qui n'est plus actif ce jour
     * porte déjà un encaissement (recette honorée par le conducteur réel). Sert de
     * garde-fou contre les doublons lors d'une modification rétroactive du programme.
     */
    private boolean dejaHonoreParChauffeurRetire(List<LigneRecette> existantes, List<Long> chauffeursActifs) {
        return existantes.stream()
                .filter(l -> !chauffeursActifs.contains(l.getChauffeurId()))
                .filter(l -> l.getStatut() != StatutLigneRecette.ANNULEE)
                .anyMatch(this::aEteEncaisse);
    }

    private boolean aEteEncaisse(LigneRecette ligne) {
        return ligne.getStatut() != StatutLigneRecette.EN_ATTENTE
                || (ligne.getMontantEncaisse() != null
                        && ligne.getMontantEncaisse().compareTo(BigDecimal.ZERO) > 0);
    }

    private BigDecimal resolveMontantAttendu(ConfigurationRecette config) {
        if (config.getTypeRecette() == TypeRecetteConfiguration.MONTANT_FIXE) {
            return config.getMontantObjectifParChauffeur();
        }
        return null; // MONTANT_REEL : pas de montant fixe attendu
    }
}
