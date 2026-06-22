package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.GetAllTypesVehiculesUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.TypeVehiculeResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.TypeVehiculeRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/types-vehicules")
@RequiredArgsConstructor
@Tag(name = "Types de Véhicules", description = "API pour la gestion des types de véhicules")
public class TypeVehiculeController {

    private final GetAllTypesVehiculesUseCase getAllTypesVehiculesUseCase;
    private final TypeVehiculeRestMapper typeVehiculeRestMapper;

    @GetMapping
    @Operation(summary = "Obtenir la liste de tous les types de véhicules", 
               description = "Retourne la liste complète des types de véhicules disponibles (TAXI, LIVRAISON, LOCATION)")
    public ResponseEntity<List<TypeVehiculeResponse>> getAllTypesVehicules() {
        var types = getAllTypesVehiculesUseCase.execute();
        var response = typeVehiculeRestMapper.toResponseList(types);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Obtenir un type de véhicule par son ID", 
               description = "Retourne les détails d'un type de véhicule spécifique")
    public ResponseEntity<TypeVehiculeResponse> getTypeVehiculeById(@PathVariable Long id) {
        // Pour l'instant, nous utilisons getAll et filtrons
        var types = getAllTypesVehiculesUseCase.execute();
        var type = types.stream()
                .filter(t -> t.getId().equals(id))
                .findFirst()
                .map(typeVehiculeRestMapper::toResponse);
        
        return type.map(ResponseEntity::ok)
                  .orElse(ResponseEntity.notFound().build());
    }
}
