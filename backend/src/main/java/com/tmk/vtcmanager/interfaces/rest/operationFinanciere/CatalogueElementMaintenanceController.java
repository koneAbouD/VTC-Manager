package com.tmk.vtcmanager.interfaces.rest.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ElementCatalogue;
import com.tmk.vtcmanager.application.domain.operation.PropositionCatalogue;
import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.CopierTarifsElementsMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.EnregistrerTarifElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.SupprimerTarifElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.CreateCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.DeleteCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.GetActifsCatalogueElementsMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.GetAllCatalogueElementsMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.ToggleActifCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance.UpdateCatalogueElementMaintenanceUseCase;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.CatalogueElementMaintenanceRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.CopieTarifsRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.TarifElementMaintenanceRequest;
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
    private final EnregistrerTarifElementMaintenanceUseCase enregistrerTarifUseCase;
    private final SupprimerTarifElementMaintenanceUseCase supprimerTarifUseCase;
    private final CopierTarifsElementsMaintenanceUseCase copierTarifsUseCase;
    private final FileStoragePort storage;

    @GetMapping
    @Operation(summary = "Lister les éléments de maintenance",
               description = "Retourne le catalogue complet (actifs ET inactifs), avec le tarif de chaque "
                       + "modèle. Destiné au paramétrage. Avec « modeleId », seuls les éléments qui ont un "
                       + "tarif pour ce modèle, et montantDefaut / image / imageUrl de ce modèle. "
                       + "Pour la saisie d'une maintenance, utiliser /actifs.")
    public List<CatalogueElementMaintenanceResponse> findAll(
            @RequestParam(required = false) Long modeleId) {
        return getAllUseCase.execute(modeleId).stream()
                .map(ec -> toResponse(ec, modeleId))
                .toList();
    }

    @GetMapping("/actifs")
    @Operation(summary = "Lister les éléments de maintenance proposés à la saisie",
               description = "Éléments actifs, triés par libellé. Avec « vehiculeId », seuls ceux qui ont un "
                       + "tarif actif pour le modèle du véhicule, avec le prix (montantDefaut) et l'image de "
                       + "ce modèle. Avec « categorieTypeId », seuls les éléments communs ou réservés à ce "
                       + "type de maintenance.")
    public List<CatalogueElementMaintenanceResponse> findActifs(
            @RequestParam(required = false) Long vehiculeId,
            @RequestParam(required = false) Long categorieTypeId) {
        PropositionCatalogue proposition = getActifsUseCase.execute(vehiculeId, categorieTypeId);
        return proposition.elements().stream()
                .map(ec -> toResponse(ec, proposition.modeleId()))
                .toList();
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Créer un élément de maintenance",
               description = "Crée un élément de catalogue, et son tarif pour « modeleId » s'il est fourni. "
                       + "Réservé au rôle ADMIN. Le libellé doit être unique.")
    public CatalogueElementMaintenanceResponse create(@Valid @RequestBody CatalogueElementMaintenanceRequest request) {
        ElementCatalogue cree = createUseCase.execute(
                CatalogueElementMaintenance.builder()
                        .libelle(request.libelle())
                        .categorieTypeId(request.categorieTypeId())
                        .build(),
                request.modeleId(), request.prix(), request.image());
        return toResponse(cree, request.modeleId());
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Mettre à jour un élément de maintenance",
               description = "Modifie ce qui vaut pour tous les modèles : le libellé et le type de maintenance. "
                       + "Prix et image se modifient par modèle (PUT /{id}/tarifs/{modeleId}). Réservé au rôle ADMIN.")
    public CatalogueElementMaintenanceResponse update(
            @PathVariable Long id, @Valid @RequestBody CatalogueElementMaintenanceRequest request) {
        CatalogueElementMaintenance maj = updateUseCase.execute(id, request.libelle(), request.categorieTypeId());
        return toResponse(new ElementCatalogue(maj, List.of()), null);
    }

    @PutMapping("/{id}/tarifs/{modeleId}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Enregistrer le tarif d'un élément pour un modèle",
               description = "Crée ou met à jour le prix, l'image et l'activation de l'élément pour ce modèle "
                       + "de véhicule. Réservé au rôle ADMIN.")
    public CatalogueElementMaintenanceResponse.TarifResponse enregistrerTarif(
            @PathVariable Long id, @PathVariable Long modeleId,
            @Valid @RequestBody TarifElementMaintenanceRequest request) {
        return toTarifResponse(enregistrerTarifUseCase.execute(id, modeleId, request.prix(), request.image(),
                !Boolean.FALSE.equals(request.actif())));
    }

    @DeleteMapping("/{id}/tarifs/{modeleId}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Retirer un élément d'un modèle",
               description = "Supprime le tarif : l'élément n'est plus proposé pour ce modèle. Les maintenances "
                       + "passées ne changent pas. Réservé au rôle ADMIN.")
    public ResponseEntity<Void> supprimerTarif(@PathVariable Long id, @PathVariable Long modeleId) {
        supprimerTarifUseCase.execute(id, modeleId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/tarifs/copier")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Reprendre pour un modèle les éléments d'un autre",
               description = "Ajoute au modèle cible les éléments du modèle source qu'il n'a pas encore, avec "
                       + "ou sans leurs prix et leurs images. Réservé au rôle ADMIN.")
    public Map<String, Integer> copierTarifs(@Valid @RequestBody CopieTarifsRequest request) {
        int copies = copierTarifsUseCase.execute(request.deModeleId(), request.versModeleId(),
                !Boolean.FALSE.equals(request.avecPrix()), !Boolean.FALSE.equals(request.avecImages()));
        return Map.of("copies", copies);
    }

    @PatchMapping("/{id}/actif")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Activer / désactiver un élément de maintenance",
               description = "Bascule le drapeau d'activation de l'élément pour tous les modèles. Réservé au "
                       + "rôle ADMIN. Corps attendu : { \"actif\": true|false }. Pour un seul modèle, utiliser "
                       + "le tarif (PUT /{id}/tarifs/{modeleId}).")
    public CatalogueElementMaintenanceResponse changerActivation(
            @PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        CatalogueElementMaintenance maj = toggleActifUseCase.execute(id, Boolean.TRUE.equals(body.get("actif")));
        return toResponse(new ElementCatalogue(maj, List.of()), null);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Supprimer un élément de maintenance",
               description = "Suppression définitive, avec ses tarifs. Réservé au rôle ADMIN. Refusée (409) si "
                       + "l'élément est déjà utilisé dans des opérations de maintenance — préférez la désactivation.")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping(value = "/image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Uploader une image d'élément de maintenance",
               description = "Envoie une image (multipart, champ « file ») et retourne son nom d'objet "
                       + "de stockage + une URL présignée. Le nom d'objet est ensuite passé dans le champ "
                       + "« image » du tarif d'un modèle (création ou PUT /{id}/tarifs/{modeleId}). "
                       + "Réservé au rôle ADMIN.")
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

    /** [modeleContexte] : modèle dont le prix et l'image remplissent la réponse. */
    private CatalogueElementMaintenanceResponse toResponse(ElementCatalogue ec, Long modeleContexte) {
        CatalogueElementMaintenance e = ec.element();
        TarifElementMaintenance tarif = ec.tarifPour(modeleContexte).orElse(null);
        return new CatalogueElementMaintenanceResponse(
                e.getId(), e.getLibelle(), e.isActif(),
                e.getCategorieTypeId(), e.getCategorieTypeLibelle(),
                tarif != null ? tarif.getModeleId() : null,
                tarif != null ? tarif.getPrix() : null,
                tarif != null ? tarif.getImage() : null,
                tarif != null ? urlImage(tarif.getImage()) : null,
                tarif != null ? tarif.isActif() : null,
                ec.tarifs().stream().map(this::toTarifResponse).toList());
    }

    private CatalogueElementMaintenanceResponse.TarifResponse toTarifResponse(TarifElementMaintenance t) {
        return new CatalogueElementMaintenanceResponse.TarifResponse(
                t.getId(), t.getModeleId(), t.getModeleNom(), t.getMarqueId(), t.getMarqueNom(),
                t.getPrix(), t.getImage(), urlImage(t.getImage()), t.isActif());
    }

    private String urlImage(String image) {
        return image != null && !image.isBlank() ? storage.presignedUrl(image, PRESIGNED_TTL) : null;
    }
}
