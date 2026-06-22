package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response.ConditionTravailResponse;
import com.tmk.vtcmanager.interfaces.rest.conditionTravail.mapper.ConditionTravailRestMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Expose la condition de travail liée à un véhicule. Cet endpoint est la
 * source unique pour les onglets recettes / cotisations / pénalités côté
 * mobile : tous les détails (objectif de recette, mode d'encaissement,
 * cotisations, pénalités, etc.) sont portés par la condition de travail.
 */
@RestController
@RequestMapping("/api/vehicules/{vehiculeId}/condition-travail")
@RequiredArgsConstructor
public class VehiculeConditionTravailController {

    private final VehiculeRepository vehiculeRepository;
    private final ConditionTravailRestMapper mapper;

    @GetMapping
    public ResponseEntity<ConditionTravailResponse> getConditionTravail(
            @PathVariable Long vehiculeId) {
        Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        if (vehicule.getConditionTravail() == null) {
            // 204 No Content : véhicule sans condition de travail liée
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.ok(
                mapper.toResponse(vehicule.getConditionTravail()));
    }
}
