package com.tmk.vtcmanager.application.usecases.programmeTravail;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ChauffeurAlreadyAssignedException;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.exception.ChauffeurPermisExpireException;
import com.tmk.vtcmanager.application.exception.ChauffeurSuspenduException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.IndisponibiliteNettoyageService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;


@RequiredArgsConstructor
public class CreateProgrammeTravailUseCase {

    private final ProgrammeTravailRepository programmeRepository;
    private final VehiculeRepository vehiculeRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final IndisponibiliteNettoyageService indisponibiliteNettoyageService;
    private final DocumentRepository documentRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;

    @Transactional
    public ProgrammeTravail execute(Long vehiculeId, ProgrammeTravail programme) {
        Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        if (vehicule.getConditionTravail() == null) {
            throw new IllegalStateException(
                    "Le véhicule doit être lié à une condition de travail avant la configuration des chauffeurs.");
        }

        // Collecter les IDs de l'ancien programme (pour désassigner les chauffeurs supprimés)
        Set<Long> anciensChauffeurIds = programmeRepository.findByVehiculeId(vehiculeId)
                .map(ancien -> ancien.getChauffeurs().stream()
                        .map(ProgrammeChauffeur::getChauffeurId)
                        .collect(Collectors.toSet()))
                .orElse(Set.of());

        programme.setVehiculeId(vehiculeId);
        programme.synchronizeWithCondition(vehicule.getConditionTravail());
        programme.normalize();
        programme.validate();

        List<Chauffeur> nouveauxChauffeurs = validateAndLoadChauffeurs(programme, vehiculeId);

        ProgrammeTravail saved = programmeRepository.save(programme);

        // Mettre à jour les affectations véhicule des chauffeurs
        Set<Long> nouveauxIds = programme.getChauffeurs().stream()
                .map(ProgrammeChauffeur::getChauffeurId)
                .collect(Collectors.toSet());

        // Assigner les nouveaux chauffeurs au véhicule
        for (Chauffeur chauffeur : nouveauxChauffeurs) {
            if (!vehiculeId.equals(getVehiculeIdOf(chauffeur))) {
                chauffeur.assignVehicule(vehicule);
                chauffeurRepository.save(chauffeur);
            }
        }

        // Désassigner les chauffeurs retirés du programme
        for (Long ancienId : anciensChauffeurIds) {
            if (!nouveauxIds.contains(ancienId)) {
                chauffeurRepository.findById(ancienId).ifPresent(c -> {
                    c.unassignVehicule();
                    chauffeurRepository.save(c);
                });
                // Indisponibilités du chauffeur retiré devenues sans effet.
                indisponibiliteNettoyageService.nettoyerSiOrphelin(ancienId);
            }
        }

        // Affectation/désaffectation effectuées → recalcul du statut du véhicule.
        statutEventPublisher.publishStatutDirty(vehiculeId);

        return saved;
    }

    private List<Chauffeur> validateAndLoadChauffeurs(ProgrammeTravail programme, Long vehiculeId) {
        List<Chauffeur> result = new ArrayList<>();
        for (ProgrammeChauffeur pc : programme.getChauffeurs()) {
            if (pc.getDateService() == null) {
                throw new IllegalArgumentException(
                        "La date de prise de service est obligatoire pour chaque chauffeur sélectionné.");
            }
            Chauffeur chauffeur = chauffeurRepository.findById(pc.getChauffeurId())
                    .orElseThrow(() -> new ChauffeurNotFoundException(pc.getChauffeurId()));
            // Verrou RH : seul un chauffeur SUSPENDU est refusé. INACTIF et EN_CONGE
            // sont autorisés (EN_CONGE = titulaire conservé, remplacé par date — overlay).
            if (chauffeur.getStatut() == ChauffeurStatus.SUSPENDU) {
                throw new ChauffeurSuspenduException(
                        chauffeur.getId(), chauffeur.getFullName(), chauffeur.getDateSuspension());
            }
            // Blocage si le permis de conduire est expiré.
            boolean permisExpire = documentRepository
                    .findByCibleAndCibleId(CibleDocument.CHAUFFEUR, chauffeur.getId())
                    .stream()
                    .anyMatch(d -> d.estPermis() && d.estExpireLe(LocalDate.now()));
            if (permisExpire) {
                throw new ChauffeurPermisExpireException(chauffeur.getId(), chauffeur.getFullName());
            }
            Long vehiculeActuelId = getVehiculeIdOf(chauffeur);
            if (vehiculeActuelId != null && !vehiculeActuelId.equals(vehiculeId)) {
                throw new ChauffeurAlreadyAssignedException(
                        chauffeur.getId(),
                        chauffeur.getFullName(),
                        vehiculeActuelId,
                        chauffeur.getVehicule().getImmatriculation());
            }
            result.add(chauffeur);
        }
        return result;
    }

    private Long getVehiculeIdOf(Chauffeur chauffeur) {
        return chauffeur.getVehicule() != null ? chauffeur.getVehicule().getId() : null;
    }
}
