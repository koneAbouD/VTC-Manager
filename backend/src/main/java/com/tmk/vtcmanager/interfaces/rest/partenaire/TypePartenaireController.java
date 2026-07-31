package com.tmk.vtcmanager.interfaces.rest.partenaire;

import com.tmk.vtcmanager.application.domain.partenaire.TypePartenaire;
import com.tmk.vtcmanager.application.usecases.partenaire.TypePartenaireReferentielUseCase;
import com.tmk.vtcmanager.interfaces.rest.partenaire.dto.request.TypePartenaireRequest;
import com.tmk.vtcmanager.interfaces.rest.partenaire.dto.response.TypePartenaireResponse;
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

/**
 * Référentiel des types de partenaire (prestataire, fournisseur,
 * administration, bailleur, assurance…).
 */
@RestController
@RequestMapping("/api/v1/types-partenaire")
@RequiredArgsConstructor
@Tag(name = "Types de partenaire", description = "Référentiel des familles de partenaires")
public class TypePartenaireController {

    private final TypePartenaireReferentielUseCase referentielUseCase;

    @GetMapping
    @Operation(summary = "Lister tous les types de partenaire (actifs ET inactifs)",
            description = "Liste complète, destinée au paramétrage. Pour la sélection, utiliser /actifs.")
    public ResponseEntity<List<TypePartenaireResponse>> lister() {
        return ResponseEntity.ok(toResponses(referentielUseCase.lister(false)));
    }

    @GetMapping("/actifs")
    @Operation(summary = "Lister les types de partenaire actifs",
            description = "Uniquement les actifs, triés par nom — destinés aux formulaires.")
    public ResponseEntity<List<TypePartenaireResponse>> listerActifs() {
        return ResponseEntity.ok(toResponses(referentielUseCase.lister(true)));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Créer un type de partenaire",
            description = "Réservé au rôle ADMIN. Le nom doit être unique.")
    public ResponseEntity<TypePartenaireResponse> creer(@Valid @RequestBody TypePartenaireRequest request) {
        var cree = referentielUseCase.creer(request.nom(), request.description());
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(cree));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Mettre à jour un type de partenaire",
            description = "Modifie le nom et la description. Réservé au rôle ADMIN.")
    public ResponseEntity<TypePartenaireResponse> mettreAJour(
            @PathVariable Long id, @Valid @RequestBody TypePartenaireRequest request) {
        return ResponseEntity.ok(toResponse(
                referentielUseCase.mettreAJour(id, request.nom(), request.description())));
    }

    @PatchMapping("/{id}/actif")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Activer / désactiver un type de partenaire",
            description = "Bascule le drapeau d'activation (soft-disable). Réservé au rôle ADMIN. "
                    + "Corps attendu : { \"actif\": true|false }.")
    public ResponseEntity<TypePartenaireResponse> changerActivation(
            @PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        return ResponseEntity.ok(toResponse(
                referentielUseCase.changerActivation(id, Boolean.TRUE.equals(body.get("actif")))));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Supprimer un type de partenaire",
            description = "Suppression définitive. Réservé au rôle ADMIN. Refusée si un partenaire "
                    + "porte encore ce type — préférez la désactivation.")
    public ResponseEntity<Void> supprimer(@PathVariable Long id) {
        referentielUseCase.supprimer(id);
        return ResponseEntity.noContent().build();
    }

    private List<TypePartenaireResponse> toResponses(List<TypePartenaire> types) {
        return types.stream().map(this::toResponse).toList();
    }

    private TypePartenaireResponse toResponse(TypePartenaire t) {
        return new TypePartenaireResponse(t.getId(), t.getNom(), t.getDescription(), t.isActif());
    }
}
