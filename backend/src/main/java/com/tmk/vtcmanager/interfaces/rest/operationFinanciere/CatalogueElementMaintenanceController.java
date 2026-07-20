package com.tmk.vtcmanager.interfaces.rest.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.CreateCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.DeleteCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.GetActifsCatalogueElementsMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.GetAllCatalogueElementsMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.ToggleActifCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.UpdateCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.CatalogueElementMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CatalogueElementImageResponse;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CatalogueElementMaintenanceResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/catalogue-elements-maintenance")
@RequiredArgsConstructor
@Tag(name = "Éléments de maintenance", description = "API de gestion du catalogue des éléments de maintenance (référentiel)")
public class CatalogueElementMaintenanceController {

    private static final String IMAGE_PREFIX = "catalogue-maintenance/images/";
    private static final int PRESIGNED_TTL = 3600;

    private final GetAllCatalogueElementsMaintenanceUseCase getAllUseCase;
    private final GetActifsCatalogueElementsMaintenanceUseCase getActifsUseCase;
    private final CreateCatalogueElementMaintenanceUseCase createUseCase;
    private final UpdateCatalogueElementMaintenanceUseCase updateUseCase;
    private final ToggleActifCatalogueElementMaintenanceUseCase toggleActifUseCase;
    private final DeleteCatalogueElementMaintenanceUseCase deleteUseCase;
    private final FileStoragePort storage;

    @GetMapping
    @Operation(summary = "Lister tous les éléments de maintenance",
               description = "Retourne la liste complète du catalogue (actifs ET inactifs). "
                       + "Destiné au paramétrage. Pour la saisie d'une maintenance, utiliser /actifs.")
    public List<CatalogueElementMaintenanceResponse> findAll() {
        return getAllUseCase.execute().stream()
                .map(this::toResponse)
                .toList();
    }

    @GetMapping("/actifs")
    @Operation(summary = "Lister les éléments de maintenance actifs",
               description = "Retourne uniquement les éléments actifs, triés par libellé — "
                       + "destinés à la sélection lors de la saisie d'une opération de maintenance.")
    public List<CatalogueElementMaintenanceResponse> findActifs() {
        return getActifsUseCase.execute().stream()
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
                CatalogueElementMaintenance.builder()
                        .libelle(request.libelle())
                        .montantDefaut(request.montantDefaut())
                        .image(request.image())
                        .build());
        return toResponse(created);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Mettre à jour un élément de maintenance",
               description = "Modifie le libellé d'un élément. Réservé au rôle ADMIN.")
    public CatalogueElementMaintenanceResponse update(
            @PathVariable Long id, @Valid @RequestBody CatalogueElementMaintenanceRequest request) {
        return toResponse(updateUseCase.execute(
                id, request.libelle(), request.montantDefaut(), request.image()));
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

    @PostMapping(value = "/image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Uploader une image d'élément de maintenance",
               description = "Envoie une image (multipart, champ « file ») et retourne son nom d'objet "
                       + "de stockage + une URL présignée. Le nom d'objet est ensuite passé dans le champ "
                       + "« image » lors de la création / mise à jour de l'élément. Réservé au rôle ADMIN.")
    public CatalogueElementImageResponse uploadImage(@RequestParam("file") MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Fichier image manquant.");
        }
        String objectName = IMAGE_PREFIX + UUID.randomUUID() + "_" + file.getOriginalFilename();
        try {
            storage.upload(objectName, file.getInputStream(), file.getSize(), file.getContentType());
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "Erreur lors de l'upload de l'image : " + e.getMessage());
        }
        return new CatalogueElementImageResponse(objectName, storage.presignedUrl(objectName, PRESIGNED_TTL));
    }

    private CatalogueElementMaintenanceResponse toResponse(CatalogueElementMaintenance e) {
        String imageUrl = e.getImage() != null && !e.getImage().isBlank()
                ? storage.presignedUrl(e.getImage(), PRESIGNED_TTL)
                : null;
        return new CatalogueElementMaintenanceResponse(
                e.getId(), e.getLibelle(), e.isActif(),
                e.getMontantDefaut(), e.getImage(), imageUrl);
    }
}
