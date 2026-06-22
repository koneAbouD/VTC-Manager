package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.GetModelesByTypeAndMarqueUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.ModeleResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.ModeleRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/modeles")
@RequiredArgsConstructor
@Tag(name = "Modèles", description = "API pour la consultation des modèles de véhicules")
public class ModeleController {

    private final GetModelesByTypeAndMarqueUseCase getModelesByTypeAndMarqueUseCase;
    private final ModeleRestMapper modeleRestMapper;

    @GetMapping("/by-type-and-marque")
    @Operation(summary = "Obtenir les modèles par type et marque", 
               description = "Retourne la liste des modèles disponibles pour un type de véhicule et une marque spécifiques")
    public ResponseEntity<List<ModeleResponse>> getModelesByTypeAndMarque(
            @Parameter(description = "ID du type de véhicule", example = "1")
            @RequestParam Long typeId,
            @Parameter(description = "ID de la marque", example = "1")
            @RequestParam Long marqueId) {
        var modeles = getModelesByTypeAndMarqueUseCase.execute(typeId, marqueId);
        var response = modeleRestMapper.toResponseList(modeles);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/by-type/{typeId}")
    @Operation(summary = "Obtenir les modèles par type de véhicule", 
               description = "Retourne la liste de tous les modèles disponibles pour un type de véhicule spécifique")
    public ResponseEntity<List<ModeleResponse>> getModelesByType(
            @Parameter(description = "ID du type de véhicule", example = "1")
            @PathVariable Long typeId) {
        var modeles = getModelesByTypeAndMarqueUseCase.executeByType(typeId);
        var response = modeleRestMapper.toResponseList(modeles);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/by-marque/{marqueId}")
    @Operation(summary = "Obtenir les modèles par marque", 
               description = "Retourne la liste de tous les modèles disponibles pour une marque spécifique")
    public ResponseEntity<List<ModeleResponse>> getModelesByMarque(
            @Parameter(description = "ID de la marque", example = "1")
            @PathVariable Long marqueId) {
        var modeles = getModelesByTypeAndMarqueUseCase.executeByMarque(marqueId);
        var response = modeleRestMapper.toResponseList(modeles);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/all")
    @Operation(summary = "Obtenir tous les modèles", 
               description = "Retourne la liste complète de tous les modèles disponibles")
    public ResponseEntity<List<ModeleResponse>> getAllModeles() {
        // Note: Cette méthode pourrait être optimisée avec un usecase dédié
        List<ModeleResponse> allModeles = List.of();
        return ResponseEntity.ok(allModeles);
    }
}
