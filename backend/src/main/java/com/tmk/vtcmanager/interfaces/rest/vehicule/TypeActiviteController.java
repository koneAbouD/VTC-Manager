package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.GetAllTypesActivitesUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.TypeActiviteReferentielUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.TypeActiviteRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.TypeActiviteResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.TypeActiviteRestMapper;
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
@RequestMapping("/api/v1/types-activites")
@RequiredArgsConstructor
@Tag(name = "Types d'Activité", description = "API pour la gestion des types d'activité")
public class TypeActiviteController {

    private final GetAllTypesActivitesUseCase getAllTypesActivitesUseCase;
    private final TypeActiviteReferentielUseCase referentielUseCase;
    private final TypeActiviteRestMapper typeActiviteRestMapper;

    @GetMapping
    @Operation(summary = "Lister tous les types d'activité")
    public ResponseEntity<List<TypeActiviteResponse>> getAllTypesActivites() {
        return ResponseEntity.ok(typeActiviteRestMapper.toResponseList(getAllTypesActivitesUseCase.execute()));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Créer un type d'activité",
               description = "Crée un nouveau type d'activité. Réservé au rôle ADMIN. Le nom doit être unique.")
    public ResponseEntity<TypeActiviteResponse> creer(@Valid @RequestBody TypeActiviteRequest request) {
        var cree = referentielUseCase.creer(request.nom(), request.description());
        return ResponseEntity.status(HttpStatus.CREATED).body(typeActiviteRestMapper.toResponse(cree));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Mettre à jour un type d'activité",
               description = "Modifie le nom et la description. Réservé au rôle ADMIN.")
    public ResponseEntity<TypeActiviteResponse> mettreAJour(
            @PathVariable Long id, @Valid @RequestBody TypeActiviteRequest request) {
        var maj = referentielUseCase.mettreAJour(id, request.nom(), request.description());
        return ResponseEntity.ok(typeActiviteRestMapper.toResponse(maj));
    }

    @PatchMapping("/{id}/actif")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Activer / désactiver un type d'activité",
               description = "Bascule le drapeau d'activation (soft-disable). Réservé au rôle ADMIN. "
                       + "Corps attendu : { \"actif\": true|false }.")
    public ResponseEntity<TypeActiviteResponse> changerActivation(
            @PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        var maj = referentielUseCase.changerActivation(id, Boolean.TRUE.equals(body.get("actif")));
        return ResponseEntity.ok(typeActiviteRestMapper.toResponse(maj));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Supprimer un type d'activité",
               description = "Suppression définitive. Réservé au rôle ADMIN. Refusée (409) si encore référencé — "
                       + "préférez la désactivation.")
    public ResponseEntity<Void> supprimer(@PathVariable Long id) {
        referentielUseCase.supprimer(id);
        return ResponseEntity.noContent().build();
    }
}