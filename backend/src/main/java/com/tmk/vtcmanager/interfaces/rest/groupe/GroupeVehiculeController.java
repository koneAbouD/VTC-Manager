package com.tmk.vtcmanager.interfaces.rest.groupe;

import com.tmk.vtcmanager.application.domain.groupe.GestionnaireGroupe;
import com.tmk.vtcmanager.application.domain.groupe.GroupeStatut;
import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import com.tmk.vtcmanager.application.ports.persistence.TypeActiviteRepository;
import com.tmk.vtcmanager.application.usecases.groupe.*;
import com.tmk.vtcmanager.interfaces.rest.groupe.dto.*;
import com.tmk.vtcmanager.interfaces.rest.groupe.mapper.GroupeVehiculeRestMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/groupes")
@RequiredArgsConstructor
@Tag(name = "Groupes de Véhicules", description = "Gestion des groupes de véhicules et de leurs gestionnaires")
public class GroupeVehiculeController {

    private final GetAllGroupesUseCase getAllGroupesUseCase;
    private final GetGroupeByIdUseCase getGroupeByIdUseCase;
    private final CreateGroupeUseCase createGroupeUseCase;
    private final DeleteGroupeUseCase deleteGroupeUseCase;
    private final AddGestionnaireUseCase addGestionnaireUseCase;
    private final RemoveGestionnaireUseCase removeGestionnaireUseCase;
    private final CheckGroupeUtilisationUseCase checkGroupeUtilisationUseCase;
    private final TypeActiviteRepository typeActiviteRepository;
    private final KeycloakAdminPort keycloakAdminPort;
    private final GroupeVehiculeRestMapper mapper;

    @GetMapping
    @Operation(summary = "Lister tous les groupes")
    public ResponseEntity<List<GroupeVehiculeResponse>> getAll() {
        List<GroupeVehicule> groupes = getAllGroupesUseCase.execute();
        // Déduplique les appels Keycloak : 1 appel par userId unique, pas 1 par groupe
        Map<String, String> usernames = new HashMap<>();
        groupes.stream()
                .map(GroupeVehicule::getGestionnaire)
                .filter(g -> g != null && g.getUserId() != null)
                .map(GestionnaireGroupe::getUserId)
                .distinct()
                .forEach(uid -> {
                    try { usernames.put(uid, keycloakAdminPort.getUserById(uid).getUsername()); }
                    catch (Exception ignored) {}
                });
        groupes.forEach(g -> {
            if (g.getGestionnaire() != null && g.getGestionnaire().getUserId() != null) {
                g.getGestionnaire().setUsername(usernames.get(g.getGestionnaire().getUserId()));
            }
        });
        return ResponseEntity.ok(mapper.toResponseList(groupes));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Détail d'un groupe")
    public ResponseEntity<GroupeVehiculeResponse> getById(@PathVariable Long id) {
        GroupeVehicule groupe = getGroupeByIdUseCase.execute(id);
        enrichGestionnaire(groupe.getGestionnaire());
        return ResponseEntity.ok(mapper.toResponse(groupe));
    }

    @PostMapping
    @Operation(summary = "Créer un groupe")
    public ResponseEntity<GroupeVehiculeResponse> create(@Valid @RequestBody CreateGroupeRequest request) {
        var builder = GroupeVehicule.builder()
                .nom(request.nom())
                .description(request.description())
                .statut(GroupeStatut.ACTIF);

        if (request.typeActiviteId() != null) {
            var typeActivite = typeActiviteRepository.findById(request.typeActiviteId())
                    .orElseThrow(() -> ResourceNotFoundException.of("TypeActivite", request.typeActiviteId()));
            builder.typeActivite(typeActivite);
        }

        GroupeVehicule created = createGroupeUseCase.execute(builder.build());

        if (request.gestionnaireUserId() != null && !request.gestionnaireUserId().isBlank()) {
            var gestionnaire = GestionnaireGroupe.builder()
                    .userId(request.gestionnaireUserId())
                    .build();
            created = addGestionnaireUseCase.execute(created.getId(), gestionnaire);
        }

        return ResponseEntity.status(HttpStatus.CREATED).body(mapper.toResponse(created));
    }

    @GetMapping("/{id}/utilisation")
    @Operation(summary = "Vérifier si un groupe est utilisé par au moins un véhicule")
    public ResponseEntity<GroupeUtilisationResponse> getUtilisation(@PathVariable Long id) {
        long nb = checkGroupeUtilisationUseCase.countVehicules(id);
        return ResponseEntity.ok(new GroupeUtilisationResponse(nb > 0, nb));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Supprimer un groupe")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        deleteGroupeUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    // ── Gestionnaire ──

    @GetMapping("/{id}/gestionnaire")
    @Operation(summary = "Gestionnaire du groupe")
    public ResponseEntity<GestionnaireGroupeResponse> getGestionnaire(@PathVariable Long id) {
        var gestionnaire = getGroupeByIdUseCase.execute(id).getGestionnaire();
        if (gestionnaire == null) return ResponseEntity.noContent().build();
        enrichGestionnaire(gestionnaire);
        return ResponseEntity.ok(mapper.toGestionnaireResponse(gestionnaire));
    }

    @PutMapping("/{id}/gestionnaire")
    @Operation(summary = "Affecter un gestionnaire au groupe")
    public ResponseEntity<GroupeVehiculeResponse> setGestionnaire(
            @PathVariable Long id,
            @Valid @RequestBody AddGestionnaireRequest request) {
        return ResponseEntity.ok(mapper.toResponse(addGestionnaireUseCase.execute(id, mapper.toDomain(request))));
    }

    @DeleteMapping("/{id}/gestionnaire")
    @Operation(summary = "Retirer le gestionnaire du groupe")
    public ResponseEntity<Void> removeGestionnaire(@PathVariable Long id) {
        removeGestionnaireUseCase.execute(id);
        return ResponseEntity.noContent().build();
    }

    private void enrichGestionnaire(GestionnaireGroupe gestionnaire) {
        if (gestionnaire == null || gestionnaire.getUserId() == null) return;
        try {
            var userInfo = keycloakAdminPort.getUserById(gestionnaire.getUserId());
            gestionnaire.setUsername(userInfo.getUsername());
        } catch (Exception ignored) {
            // userId inconnu dans Keycloak : on laisse username null
        }
    }
}