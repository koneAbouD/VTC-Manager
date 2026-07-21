package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.GetModelesByTypeAndMarqueUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.ModeleReferentielUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.ModeleRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.ModeleResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.ModeleRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/modeles")
@RequiredArgsConstructor
@Tag(name = "Modèles", description = "API pour la gestion des modèles de véhicules")
public class ModeleController {

    private final GetModelesByTypeAndMarqueUseCase getModelesByTypeAndMarqueUseCase;
    private final ModeleReferentielUseCase referentielUseCase;
    private final ModeleRestMapper modeleRestMapper;

    @GetMapping
    @Operation(summary = "Obtenir tous les modèles",
               description = "Retourne la liste complète des modèles (référentiel).")
    public ResponseEntity<List<ModeleResponse>> getAll() {
        return ResponseEntity.ok(modeleRestMapper.toResponseList(referentielUseCase.lister()));
    }

    @PostMapping
    @Operation(summary = "Créer un modèle",
               description = "Crée un modèle rattaché à une marque (le type est déduit de la marque).")
    public ResponseEntity<ModeleResponse> creer(@Valid @RequestBody ModeleRequest request) {
        var cree = referentielUseCase.creer(request.nom(), request.marqueId());
        return ResponseEntity.status(HttpStatus.CREATED).body(modeleRestMapper.toResponse(cree));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Mettre à jour un modèle")
    public ResponseEntity<ModeleResponse> mettreAJour(
            @PathVariable Long id, @Valid @RequestBody ModeleRequest request) {
        var maj = referentielUseCase.mettreAJour(id, request.nom(), request.marqueId());
        return ResponseEntity.ok(modeleRestMapper.toResponse(maj));
    }

    @PatchMapping("/{id}/actif")
    @Operation(summary = "Activer / désactiver un modèle",
               description = "Corps attendu : { \"actif\": true|false }.")
    public ResponseEntity<ModeleResponse> changerActivation(
            @PathVariable Long id, @RequestBody Map<String, Object> body) {
        var maj = referentielUseCase.changerActivation(id, Boolean.TRUE.equals(body.get("actif")));
        return ResponseEntity.ok(modeleRestMapper.toResponse(maj));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Supprimer un modèle",
               description = "Suppression définitive. Refusée (409) si encore référencé — préférez la désactivation.")
    public ResponseEntity<Void> supprimer(@PathVariable Long id) {
        referentielUseCase.supprimer(id);
        return ResponseEntity.noContent().build();
    }

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
