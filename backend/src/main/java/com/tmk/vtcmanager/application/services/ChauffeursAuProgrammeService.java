package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Qui doit conduire à une date donnée.
 *
 * <p>Être « en service » et « rouler aujourd'hui » sont deux choses : le statut
 * dit qu'un chauffeur est en poste et affecté à un véhicule, le planning dit si
 * c'est son tour. Un binôme en alternance a deux chauffeurs en service, dont un
 * seul au volant chaque jour.
 *
 * <p>La réponse est celle que suivent déjà les générations de recette et de
 * cotisation — jours de travail du véhicule, alternance, puis substitution du
 * titulaire indisponible par son remplaçant. Une seule vérité : ce qui est
 * facturé au chauffeur, et ce que la liste montre de lui.
 */
@RequiredArgsConstructor
public class ChauffeursAuProgrammeService {

    private final ProgrammeTravailRepository programmeTravailRepository;
    private final IndisponibiliteSubstitutionService substitutionService;

    /**
     * Identifiants des chauffeurs attendus au volant à cette date.
     *
     * <p>Tout est lu en deux requêtes — les programmes avec leurs chauffeurs,
     * les indisponibilités — puis croisé en mémoire : marquer une liste entière
     * ne doit pas coûter une requête par chauffeur.
     */
    public Set<Long> chauffeurIds(LocalDate date) {
        Map<Long, Long> substitutions = substitutionService.substitutionsForDate(date);
        Set<Long> auVolant = new HashSet<>();

        for (ProgrammeTravail programme : programmeTravailRepository.findAllWithChauffeurs()) {
            if (!programme.travailleCeJour(date)) {
                continue;
            }
            for (Long chauffeurId : programme.chauffeursActifs(date)) {
                // Le titulaire indisponible cède sa place : c'est le remplaçant
                // qui roule, et c'est lui que la liste doit montrer en service.
                auVolant.add(substitutions.getOrDefault(chauffeurId, chauffeurId));
            }
        }
        return auVolant;
    }

    /**
     * Ce chauffeur est-il attendu au volant à cette date ?
     *
     * <p>Passe par le planning complet plutôt que par le seul programme de son
     * véhicule : un remplaçant conduit un véhicule dont il n'est pas titulaire,
     * l'indisponibilité ne touchant jamais les assignations du programme.
     */
    public boolean estAuProgramme(Long chauffeurId, LocalDate date) {
        return chauffeurId != null && chauffeurIds(date).contains(chauffeurId);
    }
}
