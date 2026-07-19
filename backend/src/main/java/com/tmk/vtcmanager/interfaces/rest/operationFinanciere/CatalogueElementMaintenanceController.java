package com.tmk.vtcmanager.interfaces.rest.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.CreateCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.DeleteCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.GetAllCatalogueElementsMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.ToggleActifCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.UpdateCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.CatalogueElementMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CatalogueElementMaintenanceResponse;
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
@RequestMapping("/api/catalogue-elements-maintenance")
@RequiredArgsConstructor
@Tag(name = "Éléments de maintenance", description = "API de gestion du catalogue des éléments de maintenance (référentiel)")
public class CatalogueElementMaintenanceController {

    private final GetAllCatalogueElementsMaintenanceUseCase getAllUseCase;
    private final CreateCatalogueElementMaintenanceUseCase createUseCase;
    private final UpdateCatalogueElementMaintenanceUseCase updateUseCase;
    private final ToggleActifCatalogueElementMaintenanceUseCase toggleActifUseCase;
    private final DeleteCatalogueElementMaintenanceUseCase deleteUseCase;

    @GetMapping
    @Operation(summary = "Lister les éléments de maintenance",
               description = "Retourne tous les éléments du catalogue de maintenance (actifs et inactifs).")
    public List<CatalogueElementMaintenanceResponse> findAll() {
        return getAllUseCase.execute().stream()
                .map(this::toResponse)
                .toList();
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Créer un élément de maintenance",
               description = "Crée un nouvel élément de catalogue. Réservé au rôle ADMIN. Le libellé doit être unique.")
    public CatalogueElementMaintenanceResponse create(@Valid @RequestBody CatalogueElementMaintenanceRequest request) {
        CatalogueElementMaintenance created = createUseCase.execute(
                CatalogueElementMaintenance.builder().libelle(request.libelle()).build());
        return toResponse(created);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Mettre à jour un élément de maintenance",
               description = "Modifie le libellé d'un élément. Réservé au rôle ADMIN.")
    public CatalogueElementMaintenanceResponse update(
            @PathVariable Long id, @Valid @RequestBody CatalogueElementMaintenanceRequest request) {
        return toResponse(updateUseCase.execute(id, request.libelle()));
    }

    @PatchMapping("/{id}/actif")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Activer / désactiver un élément de maintenance",
               description = "Bascule le drapeau d'activation (soft-disable). Réservé au rôle ADMIN. "
                       + "Corps attendu : { \"actif\": true|false }. Un élément inactif n'est plus proposé à "
                       + "la saisie mais reste dans l'historique.")
    public CatalogueElementMaintenanceResponse changerActivation(
            @PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        return toResponse(toggleActifUseCase.execute(id, Boolean.TRUE.equals(body.get("actif"))));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Supprimer un élément de maintenance",
               description = "Suppression définitive. Réservé au rôle ADMIN. Refusée (409) si l'élément est "
                       + "déjà utilisé dans des opérations de maintenance — préférez la désactivation.")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    private CatalogueElementMaintenanceResponse toResponse(CatalogueElementMaintenance e) {
        return new CatalogueElementMaintenanceResponse(e.getId(), e.getLibelle(), e.isActif());
    }
}
