package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.GetAllTypesVehiculesUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.TypeVehiculeReferentielUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.TypeVehiculeRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.TypeVehiculeResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.TypeVehiculeRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/types-vehicules")
@RequiredArgsConstructor
@Tag(name = "Types de Véhicules", description = "API pour la gestion des types de véhicules")
public class TypeVehiculeController {

    private final GetAllTypesVehiculesUseCase getAllTypesVehiculesUseCase;
    private final TypeVehiculeReferentielUseCase referentielUseCase;
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

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Créer un type de véhicule",
               description = "Crée un nouveau type de véhicule. Réservé au rôle ADMIN. Le nom doit être unique.")
    public ResponseEntity<TypeVehiculeResponse> creer(@Valid @RequestBody TypeVehiculeRequest request) {
        var cree = referentielUseCase.creer(request.nom(), request.description());
        return ResponseEntity.status(HttpStatus.CREATED).body(typeVehiculeRestMapper.toResponse(cree));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Mettre à jour un type de véhicule",
               description = "Modifie le nom et la description. Réservé au rôle ADMIN.")
    public ResponseEntity<TypeVehiculeResponse> mettreAJour(
            @PathVariable Long id, @Valid @RequestBody TypeVehiculeRequest request) {
        var maj = referentielUseCase.mettreAJour(id, request.nom(), request.description());
        return ResponseEntity.ok(typeVehiculeRestMapper.toResponse(maj));
    }

    @PatchMapping("/{id}/actif")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Activer / désactiver un type de véhicule",
               description = "Bascule le drapeau d'activation (soft-disable). Réservé au rôle ADMIN. "
                       + "Corps attendu : { \"actif\": true|false }.")
    public ResponseEntity<TypeVehiculeResponse> changerActivation(
            @PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        var maj = referentielUseCase.changerActivation(id, Boolean.TRUE.equals(body.get("actif")));
        return ResponseEntity.ok(typeVehiculeRestMapper.toResponse(maj));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Supprimer un type de véhicule",
               description = "Suppression définitive. Réservé au rôle ADMIN. Refusée (409) si le type est "
                       + "encore référencé par des véhicules — préférez la désactivation.")
    public ResponseEntity<Void> supprimer(@PathVariable Long id) {
        referentielUseCase.supprimer(id);
        return ResponseEntity.noContent().build();
    }
}
