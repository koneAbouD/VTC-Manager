package com.tmk.vtcmanager.interfaces.rest.vehicule;

import com.tmk.vtcmanager.application.usecases.vehicule.BaliseReferentielUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.GetActifsBalisesUseCase;
import com.tmk.vtcmanager.application.usecases.vehicule.GetAllBalisesUseCase;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request.BaliseRequest;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.BaliseResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.mapper.BaliseRestMapper;
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
@RequestMapping("/api/v1/balises")
@RequiredArgsConstructor
@Tag(name = "Balises GPS", description = "API pour la gestion des balises GPS")
public class BaliseController {

    private final GetAllBalisesUseCase getAllBalisesUseCase;
    private final GetActifsBalisesUseCase getActifsBalisesUseCase;
    private final BaliseReferentielUseCase referentielUseCase;
    private final BaliseRestMapper baliseRestMapper;

    @GetMapping
    @Operation(summary = "Lister toutes les balises (actives ET inactives)",
               description = "Liste complète, destinée au paramétrage. Pour la sélection, utiliser /actifs.")
    public ResponseEntity<List<BaliseResponse>> getAllBalises() {
        return ResponseEntity.ok(baliseRestMapper.toResponseList(getAllBalisesUseCase.execute()));
    }

    @GetMapping("/actifs")
    @Operation(summary = "Lister les balises actives",
               description = "Uniquement les actives, triées par identifiant — destinées à la sélection dans les formulaires.")
    public ResponseEntity<List<BaliseResponse>> getActifsBalises() {
        return ResponseEntity.ok(baliseRestMapper.toResponseList(getActifsBalisesUseCase.execute()));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Créer une balise",
               description = "Crée une nouvelle balise. Réservé au rôle ADMIN. L'identifiant doit être unique.")
    public ResponseEntity<BaliseResponse> creer(@Valid @RequestBody BaliseRequest request) {
        var cree = referentielUseCase.creer(request.identifiant(), request.numeroTelephone());
        return ResponseEntity.status(HttpStatus.CREATED).body(baliseRestMapper.toResponse(cree));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Mettre à jour une balise",
               description = "Modifie l'identifiant et le numéro de téléphone. Réservé au rôle ADMIN.")
    public ResponseEntity<BaliseResponse> mettreAJour(
            @PathVariable Long id, @Valid @RequestBody BaliseRequest request) {
        var maj = referentielUseCase.mettreAJour(id, request.identifiant(), request.numeroTelephone());
        return ResponseEntity.ok(baliseRestMapper.toResponse(maj));
    }

    @PatchMapping("/{id}/actif")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Activer / désactiver une balise",
               description = "Bascule le drapeau d'activation (soft-disable). Réservé au rôle ADMIN. "
                       + "Corps attendu : { \"actif\": true|false }.")
    public ResponseEntity<BaliseResponse> changerActivation(
            @PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        var maj = referentielUseCase.changerActivation(id, Boolean.TRUE.equals(body.get("actif")));
        return ResponseEntity.ok(baliseRestMapper.toResponse(maj));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Supprimer une balise",
               description = "Suppression définitive. Réservé au rôle ADMIN. Refusée (409) si encore référencée — "
                       + "préférez la désactivation.")
    public ResponseEntity<Void> supprimer(@PathVariable Long id) {
        referentielUseCase.supprimer(id);
        return ResponseEntity.noContent().build();
    }
}
