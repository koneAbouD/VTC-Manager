package com.tmk.vtcmanager.interfaces.rest.admin;

import com.tmk.vtcmanager.application.usecases.admin.*;
import com.tmk.vtcmanager.interfaces.rest.admin.dto.AssignRoleRequestDto;
import com.tmk.vtcmanager.interfaces.rest.admin.dto.SetEnabledRequestDto;
import com.tmk.vtcmanager.interfaces.rest.admin.dto.UpdateUserRequestDto;
import com.tmk.vtcmanager.interfaces.rest.admin.mapper.AdminRestMapper;
import com.tmk.vtcmanager.interfaces.rest.auth.dto.UserInfoDto;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
@Tag(name = "Administration", description = "Gestion des utilisateurs et rôles (RBAC) — réservé aux administrateurs")
public class AdminController {

    private final GetAllUsersUseCase getAllUsersUseCase;
    private final GetUserByIdUseCase getUserByIdUseCase;
    private final UpdateUserUseCase updateUserUseCase;
    private final DeleteUserUseCase deleteUserUseCase;
    private final SetUserEnabledUseCase setUserEnabledUseCase;
    private final GetAllRealmRolesUseCase getAllRealmRolesUseCase;
    private final AssignRoleUseCase assignRoleUseCase;
    private final RemoveRoleUseCase removeRoleUseCase;
    private final AdminRestMapper mapper;

    // ── Gestion des utilisateurs ──

    @GetMapping("/users")
    @Operation(summary = "Lister les utilisateurs", description = "Récupère tous les utilisateurs du realm Keycloak")
    public ResponseEntity<List<UserInfoDto>> getAllUsers() {
        return ResponseEntity.ok(getAllUsersUseCase.execute().stream()
                .map(mapper::toUserInfoDto)
                .toList());
    }

    @GetMapping("/users/{userId}")
    @Operation(summary = "Détail d'un utilisateur", description = "Récupère un utilisateur avec ses rôles")
    public ResponseEntity<UserInfoDto> getUser(@PathVariable String userId) {
        return ResponseEntity.ok(mapper.toUserInfoDto(getUserByIdUseCase.execute(userId)));
    }

    @PutMapping("/users/{userId}")
    @Operation(summary = "Modifier un utilisateur", description = "Met à jour les informations d'un utilisateur")
    public ResponseEntity<UserInfoDto> updateUser(
            @PathVariable String userId,
            @Valid @RequestBody UpdateUserRequestDto request) {
        return ResponseEntity.ok(mapper.toUserInfoDto(updateUserUseCase.execute(userId, mapper.toDomain(request))));
    }

    @DeleteMapping("/users/{userId}")
    @Operation(summary = "Supprimer un utilisateur")
    public ResponseEntity<Void> deleteUser(@PathVariable String userId) {
        deleteUserUseCase.execute(userId);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/users/{userId}/enabled")
    @Operation(summary = "Activer/désactiver un utilisateur")
    public ResponseEntity<Void> setUserEnabled(
            @PathVariable String userId,
            @Valid @RequestBody SetEnabledRequestDto request) {
        setUserEnabledUseCase.execute(userId, request.enabled());
        return ResponseEntity.noContent().build();
    }

    // ── Gestion des rôles ──

    @GetMapping("/roles")
    @Operation(summary = "Lister les rôles", description = "Récupère tous les rôles realm disponibles")
    public ResponseEntity<List<String>> getAllRoles() {
        return ResponseEntity.ok(getAllRealmRolesUseCase.execute());
    }

    @GetMapping("/users/{userId}/roles")
    @Operation(summary = "Rôles d'un utilisateur", description = "Récupère les rôles assignés à un utilisateur")
    public ResponseEntity<List<String>> getUserRoles(@PathVariable String userId) {
        return ResponseEntity.ok(getUserByIdUseCase.execute(userId).getRoles());
    }

    @PostMapping("/users/{userId}/roles")
    @Operation(summary = "Assigner un rôle", description = "Assigne un rôle realm à un utilisateur")
    public ResponseEntity<Void> assignRole(
            @PathVariable String userId,
            @Valid @RequestBody AssignRoleRequestDto request) {
        assignRoleUseCase.execute(userId, request.roleName());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/users/{userId}/roles/{roleName}")
    @Operation(summary = "Retirer un rôle", description = "Retire un rôle realm d'un utilisateur")
    public ResponseEntity<Void> removeRole(
            @PathVariable String userId,
            @PathVariable String roleName) {
        removeRoleUseCase.execute(userId, roleName);
        return ResponseEntity.noContent().build();
    }
}