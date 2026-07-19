package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.GetMarquesByTypeVehiculeUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.MarqueReferentielUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.MarqueRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.MarqueResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.MarqueRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
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
@RequestMapping("/api/v1/marques")
@RequiredArgsConstructor
@Tag(name = "Marques", description = "API pour la gestion des marques de véhicules")
public class MarqueController {

    private final GetMarquesByTypeVehiculeUseCase getMarquesByTypeVehiculeUseCase;
    private final MarqueReferentielUseCase referentielUseCase;
    private final MarqueRestMapper marqueRestMapper;

    @GetMapping
    @Operation(summary = "Obtenir toutes les marques",
               description = "Retourne la liste complète des marques.")
    public ResponseEntity<List<MarqueResponse>> getAllMarques() {
        return ResponseEntity.ok(marqueRestMapper.toResponseList(referentielUseCase.lister()));
    }

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

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Créer une marque",
               description = "Crée une nouvelle marque rattachée à un type de véhicule. Réservé au rôle ADMIN.")
    public ResponseEntity<MarqueResponse> creer(@Valid @RequestBody MarqueRequest request) {
        var cree = referentielUseCase.creer(request.nom(), request.typeId(), request.paysOrigine());
        return ResponseEntity.status(HttpStatus.CREATED).body(marqueRestMapper.toResponse(cree));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Mettre à jour une marque",
               description = "Modifie le nom, le type rattaché et le pays. Réservé au rôle ADMIN.")
    public ResponseEntity<MarqueResponse> mettreAJour(
            @PathVariable Long id, @Valid @RequestBody MarqueRequest request) {
        var maj = referentielUseCase.mettreAJour(id, request.nom(), request.typeId(), request.paysOrigine());
        return ResponseEntity.ok(marqueRestMapper.toResponse(maj));
    }

    @PatchMapping("/{id}/actif")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Activer / désactiver une marque",
               description = "Bascule le drapeau d'activation (soft-disable). Réservé au rôle ADMIN. "
                       + "Corps attendu : { \"actif\": true|false }.")
    public ResponseEntity<MarqueResponse> changerActivation(
            @PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        var maj = referentielUseCase.changerActivation(id, Boolean.TRUE.equals(body.get("actif")));
        return ResponseEntity.ok(marqueRestMapper.toResponse(maj));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Supprimer une marque",
               description = "Suppression définitive. Réservé au rôle ADMIN. Refusée (409) si encore référencée — "
                       + "préférez la désactivation.")
    public ResponseEntity<Void> supprimer(@PathVariable Long id) {
        referentielUseCase.supprimer(id);
        return ResponseEntity.noContent().build();
    }
}
