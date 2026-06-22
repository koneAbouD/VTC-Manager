package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;

@RequiredArgsConstructor
public class CreateLignePenaliteUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;
    private final VehiculeRepository vehiculeRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final ConditionTravailRepository conditionTravailRepository;

    @Transactional
    public LignePenalite executer(LignePenalite commande) {
        vehiculeRepository.findById(commande.getVehiculeId())
                .orElseThrow(() -> new VehiculeNotFoundException(commande.getVehiculeId()));
        chauffeurRepository.findById(commande.getChauffeurId())
                .orElseThrow(() -> new ChauffeurNotFoundException(commande.getChauffeurId()));

        LignePenalite ligne = LignePenalite.builder()
                .vehiculeId(commande.getVehiculeId())
                .chauffeurId(commande.getChauffeurId())
                .penaliteTemplateId(commande.getPenaliteTemplateId())
                .typePenalite(commande.getTypePenalite())
                .typeSanction(commande.getTypeSanction())
                .montant(commande.getMontant() != null ? commande.getMontant() : BigDecimal.ZERO)
                .montantEncaisse(BigDecimal.ZERO)
                .dureeSanctionSecondes(commande.getDureeSanctionSecondes())
                .dureeImmobilisationMinutes(commande.getDureeImmobilisationMinutes())
                .dateGeneration(LocalDate.now())
                .dateFaute(commande.getDateFaute() != null ? commande.getDateFaute() : LocalDate.now())
                .ligneRecetteId(commande.getLigneRecetteId())
                .statut(StatutLignePenalite.EN_ATTENTE)
                .encaissements(new ArrayList<>())
                .commentaire(commande.getCommentaire())
                .build();

        return lignePenaliteRepository.save(ligne);
    }

    @Transactional
    public LignePenalite signalerRetard(Long vehiculeId, Long chauffeurId,
                                        LocalDate dateFaute, String commentaire) {
        vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        chauffeurRepository.findById(chauffeurId)
                .orElseThrow(() -> new ChauffeurNotFoundException(chauffeurId));

        ConditionTravail condition = conditionTravailRepository.findByVehiculeId(vehiculeId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Aucune condition de travail avec pénalités pour ce véhicule."));
        if (condition.getPenalites() == null || condition.getPenalites().isEmpty()) {
            throw new ResourceNotFoundException("Aucune pénalité définie pour ce véhicule.");
        }

        PenaliteTemplate template = condition.getPenalites().stream()
                .filter(p -> TypePenalite.HEURE_FIN_SERVICE_PASSE.name().equals(p.getTypePenalite()))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Aucune pénalité HEURE_FIN_SERVICE_PASSE définie pour ce véhicule."));

        TypeSanction typeSanction = TypeSanction.valueOf(template.getTypeSanction());

        LignePenalite ligne = LignePenalite.builder()
                .vehiculeId(vehiculeId)
                .chauffeurId(chauffeurId)
                .penaliteTemplateId(template.getId())
                .typePenalite(TypePenalite.HEURE_FIN_SERVICE_PASSE)
                .typeSanction(typeSanction)
                .montant(template.getMontant() != null ? BigDecimal.valueOf(template.getMontant()) : BigDecimal.ZERO)
                .montantEncaisse(BigDecimal.ZERO)
                .dureeSanctionSecondes(template.getDureeSanctionSecondes())
                .dureeImmobilisationMinutes(template.getDureeImmobilisationMinutes())
                .dateGeneration(LocalDate.now())
                .dateFaute(dateFaute)
                .statut(StatutLignePenalite.EN_ATTENTE)
                .encaissements(new ArrayList<>())
                .commentaire(commentaire)
                .build();

        return lignePenaliteRepository.save(ligne);
    }
}
