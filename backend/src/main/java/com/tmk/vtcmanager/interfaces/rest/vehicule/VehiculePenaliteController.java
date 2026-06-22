package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.request.PenaliteTemplateRequest;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response.PenaliteTemplateResponse;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.mapper.ConditionTravailRestMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Collections;
import java.util.List;

/**
 * Pénalités appliquées à un véhicule. Elles sont héritées de la condition de
 * travail liée au véhicule (single source of truth). La modification met à
 * jour le template de la condition — les véhicules partageant cette condition
 * voient donc les changements répercutés.
 */
@RestController
@RequestMapping("/api/vehicules/{vehiculeId}/penalites")
@RequiredArgsConstructor
public class VehiculePenaliteController {

    private final VehiculeRepository vehiculeRepository;
    private final ConditionTravailRepository conditionTravailRepository;
    private final ConditionTravailRestMapper mapper;

    @GetMapping
    public List<PenaliteTemplateResponse> getPenalites(@PathVariable Long vehiculeId) {
        Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        ConditionTravail condition = vehicule.getConditionTravail();
        if (condition == null) {
            return Collections.emptyList();
        }
        return mapper.toPenaliteResponseList(
                condition.getPenalites() == null
                        ? Collections.emptyList()
                        : condition.getPenalites());
    }

    @PutMapping
    @Transactional
    public List<PenaliteTemplateResponse> updatePenalites(
            @PathVariable Long vehiculeId,
            @Valid @RequestBody List<PenaliteTemplateRequest> requests) {
        Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        ConditionTravail condition = vehicule.getConditionTravail();
        if (condition == null) {
            throw new IllegalStateException(
                    "Le véhicule doit être lié à une condition de travail avant la modification des pénalités.");
        }

        // Recharger la condition (entité managée) pour persister via repository
        ConditionTravail managed = conditionTravailRepository.findById(condition.getId())
                .orElseThrow(() -> ResourceNotFoundException.of("ConditionTravail", condition.getId()));

        List<PenaliteTemplate> nouvelles = mapper.toPenaliteDomainList(requests);
        managed.setPenalites(nouvelles);
        ConditionTravail updated = conditionTravailRepository.save(managed);

        return mapper.toPenaliteResponseList(
                updated.getPenalites() == null
                        ? Collections.emptyList()
                        : updated.getPenalites());
    }
}
