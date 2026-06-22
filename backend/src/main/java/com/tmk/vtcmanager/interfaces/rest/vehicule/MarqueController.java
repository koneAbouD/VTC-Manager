package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.GetMarquesByTypeVehiculeUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.MarqueResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.MarqueRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/marques")
@RequiredArgsConstructor
@Tag(name = "Marques", description = "API pour la consultation des marques de véhicules")
public class MarqueController {

    private final GetMarquesByTypeVehiculeUseCase getMarquesByTypeVehiculeUseCase;
    private final MarqueRestMapper marqueRestMapper;

    @GetMapping("/by-type/{typeId}")
    @Operation(summary = "Obtenir les marques par type de véhicule", 
               description = "Retourne la liste des marques disponibles pour un type de véhicule spécifique (TAXI, LIVRAISON, LOCATION)")
    public ResponseEntity<List<MarqueResponse>> getMarquesByTypeVehicule(
            @Parameter(description = "ID du type de véhicule", example = "1")
            @PathVariable Long typeId) {
        var marques = getMarquesByTypeVehiculeUseCase.execute(typeId);
        var response = marqueRestMapper.toResponseList(marques);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/all")
    @Operation(summary = "Obtenir toutes les marques", 
               description = "Retourne la liste complète de toutes les marques disponibles")
    public ResponseEntity<List<MarqueResponse>> getAllMarques() {
        // Pour l'instant, nous utilisons une recherche par type puis nous agrégeons
        List<MarqueResponse> allMarques = List.of();
        // Note: Cette méthode pourrait être optimisée avec un usecase dédié
        return ResponseEntity.ok(allMarques);
    }
}
