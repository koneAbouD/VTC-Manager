package com.tmk.vtcmanager.interfaces.rest.utilisateur;

import com.tmk.vtcmanager.application.domain.auth.RegisterRequest;
import com.tmk.vtcmanager.application.usecases.admin.CreateGestionnaireUseCase;
import com.tmk.vtcmanager.application.usecases.admin.GetUsersByRoleUseCase;
import com.tmk.vtcmanager.interfaces.rest.admin.mapper.AdminRestMapper;
import com.tmk.vtcmanager.interfaces.rest.auth.dto.UserInfoDto;
import com.tmk.vtcmanager.interfaces.rest.utilisateur.dto.CreateGestionnaireRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/utilisateurs")
@RequiredArgsConstructor
@Tag(name = "Utilisateurs", description = "Gestion des utilisateurs par rôle")
public class UtilisateurController {

    private final GetUsersByRoleUseCase getUsersByRoleUseCase;
    private final CreateGestionnaireUseCase createGestionnaireUseCase;
    private final AdminRestMapper mapper;

    @GetMapping("/gestionnaires")
    @Operation(summary = "Lister les gestionnaires",
            description = "Récupère tous les utilisateurs ayant le rôle GESTIONNAIRE")
    public ResponseEntity<List<UserInfoDto>> getGestionnaires() {
        return ResponseEntity.ok(
                getUsersByRoleUseCase.execute("GESTIONNAIRE").stream()
                        .map(mapper::toUserInfoDto)
                        .toList()
        );
    }

    @PostMapping("/gestionnaires")
    @Operation(summary = "Créer un gestionnaire",
            description = "Crée un utilisateur Keycloak avec le rôle GESTIONNAIRE automatiquement assigné")
    public ResponseEntity<UserInfoDto> createGestionnaire(
            @Valid @RequestBody CreateGestionnaireRequest request) {
        var created = createGestionnaireUseCase.execute(
                RegisterRequest.builder()
                        .username(request.username())
                        .email(request.email())
                        .firstName(request.firstName())
                        .lastName(request.lastName())
                        .phone(request.phone())
                        .build()
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(mapper.toUserInfoDto(created));
    }
}