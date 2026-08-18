package com.tmk.vtcmanager.interfaces.rest.utilisateur;

import com.tmk.vtcmanager.application.domain.auth.RegisterRequest;
import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.usecases.admin.CreateGestionnaireUseCase;
import com.tmk.vtcmanager.application.usecases.admin.GetUserByIdUseCase;
import com.tmk.vtcmanager.application.usecases.admin.GetUsersByRoleUseCase;
import com.tmk.vtcmanager.application.usecases.admin.UpdateUserUseCase;
import com.tmk.vtcmanager.interfaces.rest.admin.mapper.AdminRestMapper;
import com.tmk.vtcmanager.interfaces.rest.auth.dto.UserInfoDto;
import com.tmk.vtcmanager.interfaces.rest.utilisateur.dto.CreateGestionnaireRequest;
import com.tmk.vtcmanager.interfaces.rest.utilisateur.dto.UpdateMonProfilRequest;
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
    private final GetUserByIdUseCase getUserByIdUseCase;
    private final UpdateUserUseCase updateUserUseCase;
    private final CurrentUserResolver currentUser;
    private final AdminRestMapper mapper;

    // ── Fiche du compte connecté ──
    // Ouvertes à tout compte authentifié (ADMIN ou GESTIONNAIRE, cf.
    // SecurityConfig) : chacun n'y voit et n'y modifie que sa propre fiche,
    // l'identité étant résolue depuis le jeton.

    @GetMapping("/moi")
    @Operation(summary = "Mes informations personnelles",
            description = "Fiche Keycloak du compte connecté, résolue depuis le jeton")
    public ResponseEntity<UserInfoDto> monProfil() {
        return ResponseEntity.ok(
                mapper.toUserInfoDto(getUserByIdUseCase.execute(currentUser.idOrThrow())));
    }

    @PutMapping("/moi")
    @Operation(summary = "Modifier mes informations personnelles",
            description = "Met à jour prénom, nom, e-mail et téléphone du compte connecté")
    public ResponseEntity<UserInfoDto> modifierMonProfil(
            @Valid @RequestBody UpdateMonProfilRequest request) {
        UserInfo modifications = UserInfo.builder()
                .firstName(request.firstName().trim())
                .lastName(request.lastName().trim())
                .email(request.email().trim())
                // Null laisse le numéro en place, chaîne vide l'efface.
                .phone(request.phone() == null ? null : request.phone().trim())
                .build();
        return ResponseEntity.ok(mapper.toUserInfoDto(
                updateUserUseCase.execute(currentUser.idOrThrow(), modifications)));
    }

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