package com.tmk.vtcmanager.infrastructure.keycloak;

import com.tmk.vtcmanager.application.domain.auth.RegisterRequest;
import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.core.Response;
import lombok.extern.slf4j.Slf4j;
import org.keycloak.admin.client.Keycloak;
import org.keycloak.admin.client.resource.RealmResource;
import org.keycloak.admin.client.resource.RoleMappingResource;
import org.keycloak.admin.client.resource.UserResource;
import org.keycloak.admin.client.resource.UsersResource;
import org.keycloak.representations.idm.CredentialRepresentation;
import org.keycloak.representations.idm.RoleRepresentation;
import org.keycloak.representations.idm.UserRepresentation;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Adapter pour les opérations d'administration Keycloak (Admin REST API).
 * Utilise le keycloak-admin-client pour la gestion des utilisateurs et des rôles.
 */
@Slf4j
@Component
public class KeycloakAdminAdapter implements KeycloakAdminPort {

    private final Keycloak keycloak;
    private final String realm;

    public KeycloakAdminAdapter(
            Keycloak keycloak,
            @Value("${app.keycloak.realm}") String realm) {
        this.keycloak = keycloak;
        this.realm = realm;
    }

    private RealmResource realmResource() {
        return keycloak.realm(realm);
    }

    private UsersResource usersResource() {
        return realmResource().users();
    }

    // ── Gestion des utilisateurs ──

    @Override
    public UserInfo createUser(RegisterRequest request) {
        UserRepresentation user = new UserRepresentation();
        user.setUsername(request.getUsername());
        user.setEmail(request.getEmail());
        user.setFirstName(request.getFirstName());
        user.setLastName(request.getLastName());
        user.setEnabled(true);
        user.setEmailVerified(false);
        if (request.getPhone() != null && !request.getPhone().isBlank()) {
            user.setAttributes(java.util.Map.of("phoneNumber", java.util.List.of(request.getPhone())));
        }

        if (request.getPassword() != null && !request.getPassword().isBlank()) {
            CredentialRepresentation credential = new CredentialRepresentation();
            credential.setType(CredentialRepresentation.PASSWORD);
            credential.setValue(request.getPassword());
            credential.setTemporary(false);
            user.setCredentials(Collections.singletonList(credential));
        } else {
            user.setRequiredActions(java.util.List.of("UPDATE_PASSWORD"));
        }

        try (Response response = usersResource().create(user)) {
            if (response.getStatus() == 201) {
                String userId = extractUserId(response);
                log.info("Utilisateur créé dans Keycloak: {}", userId);

                // Assigner les rôles si spécifiés
                if (request.getRoles() != null && !request.getRoles().isEmpty()) {
                    for (String roleName : request.getRoles()) {
                        assignRealmRole(userId, roleName);
                    }
                }

                return getUserById(userId);
            } else if (response.getStatus() == 409) {
                throw new IllegalArgumentException("Un utilisateur avec ce nom ou email existe déjà");
            } else {
                throw new RuntimeException(
                        "Erreur lors de la création de l'utilisateur: HTTP " + response.getStatus());
            }
        }
    }

    @Override
    public void sendResetPasswordEmail(String email) {
        List<UserRepresentation> users = usersResource().searchByEmail(email, true);
        if (users.isEmpty()) {
            throw new com.tmk.vtcmanager.application.exception.ResourceNotFoundException(
                    "Aucun utilisateur trouvé avec l'email: " + email);
        }
        String userId = users.get(0).getId();
        try {
            usersResource().get(userId).executeActionsEmail(List.of("UPDATE_PASSWORD"));
            log.info("Email de réinitialisation envoyé à: {}", email);
        } catch (Exception e) {
            log.error("Erreur envoi email reset password: {}", e.getMessage());
            throw new RuntimeException("Erreur lors de l'envoi de l'email de réinitialisation");
        }
    }

    @Override
    public void resetPassword(String userId, String newPassword) {
        CredentialRepresentation credential = new CredentialRepresentation();
        credential.setType(CredentialRepresentation.PASSWORD);
        credential.setValue(newPassword);
        credential.setTemporary(false);
        try {
            usersResource().get(userId).resetPassword(credential);
        } catch (Exception e) {
            log.error("Erreur reset password Keycloak pour {}: {}", userId, e.getMessage());
            throw new RuntimeException("Impossible de réinitialiser le mot de passe de l'utilisateur");
        }
    }

    @Override
    public void markAccountReady(String userId) {
        try {
            UserResource userResource = usersResource().get(userId);
            UserRepresentation user = userResource.toRepresentation();
            user.setEnabled(true);
            user.setEmailVerified(true);
            user.setRequiredActions(java.util.List.of());
            userResource.update(user);
            log.info("Compte Keycloak {} marqué prêt (aucune required action)", userId);
        } catch (Exception e) {
            log.error("Erreur markAccountReady Keycloak pour {}: {}", userId, e.getMessage());
            throw new RuntimeException("Impossible de finaliser la configuration du compte");
        }
    }

    @Override
    public List<UserInfo> getAllUsers() {
        return usersResource().list().stream()
                .map(this::toUserInfo)
                .collect(Collectors.toList());
    }

    @Override
    public UserInfo getUserById(String userId) {
        try {
            UserRepresentation user = usersResource().get(userId).toRepresentation();
            UserInfo info = toUserInfo(user);
            info.setRoles(getUserRoles(userId));
            return info;
        } catch (NotFoundException e) {
            throw new com.tmk.vtcmanager.application.exception.ResourceNotFoundException(
                    "Utilisateur non trouvé: " + userId);
        }
    }

    @Override
    public UserInfo getUserByEmail(String email) {
        List<UserRepresentation> users = usersResource().searchByEmail(email, true);
        if (users.isEmpty()) {
            throw new com.tmk.vtcmanager.application.exception.ResourceNotFoundException(
                    "Aucun utilisateur trouvé avec l'email: " + email);
        }
        UserInfo info = toUserInfo(users.get(0));
        info.setRoles(getUserRoles(users.get(0).getId()));
        return info;
    }

    @Override
    public java.util.Optional<String> findUserIdByUsername(String username) {
        List<UserRepresentation> users = usersResource().searchByUsername(username, true);
        return users.stream()
                .filter(u -> username.equalsIgnoreCase(u.getUsername()))
                .map(UserRepresentation::getId)
                .findFirst();
    }

    @Override
    public UserInfo updateUser(String userId, UserInfo userInfo) {
        try {
            UserResource userResource = usersResource().get(userId);
            UserRepresentation user = userResource.toRepresentation();

            if (userInfo.getEmail() != null) user.setEmail(userInfo.getEmail());
            if (userInfo.getFirstName() != null) user.setFirstName(userInfo.getFirstName());
            if (userInfo.getLastName() != null) user.setLastName(userInfo.getLastName());
            if (userInfo.getUsername() != null) user.setUsername(userInfo.getUsername());

            userResource.update(user);
            log.info("Utilisateur mis à jour: {}", userId);
            return getUserById(userId);

        } catch (NotFoundException e) {
            throw new com.tmk.vtcmanager.application.exception.ResourceNotFoundException(
                    "Utilisateur non trouvé: " + userId);
        }
    }

    @Override
    public void deleteUser(String userId) {
        try {
            usersResource().get(userId).remove();
            log.info("Utilisateur supprimé: {}", userId);
        } catch (NotFoundException e) {
            throw new com.tmk.vtcmanager.application.exception.ResourceNotFoundException(
                    "Utilisateur non trouvé: " + userId);
        }
    }

    @Override
    public void setUserEnabled(String userId, boolean enabled) {
        try {
            UserResource userResource = usersResource().get(userId);
            UserRepresentation user = userResource.toRepresentation();
            user.setEnabled(enabled);
            userResource.update(user);
            log.info("Utilisateur {} {}", userId, enabled ? "activé" : "désactivé");
        } catch (NotFoundException e) {
            throw new com.tmk.vtcmanager.application.exception.ResourceNotFoundException(
                    "Utilisateur non trouvé: " + userId);
        }
    }

    // ── Gestion des rôles ──

    @Override
    public List<String> getAllRealmRoles() {
        return realmResource().roles().list().stream()
                .map(RoleRepresentation::getName)
                .filter(name -> !name.startsWith("uma_") && !name.equals("offline_access")
                        && !name.equals("default-roles-" + realm))
                .collect(Collectors.toList());
    }

    @Override
    public List<String> getUserRoles(String userId) {
        try {
            RoleMappingResource roleMappings = usersResource().get(userId).roles();
            return roleMappings.realmLevel().listEffective().stream()
                    .map(RoleRepresentation::getName)
                    .filter(name -> !name.startsWith("uma_") && !name.equals("offline_access")
                            && !name.equals("default-roles-" + realm))
                    .collect(Collectors.toList());
        } catch (NotFoundException e) {
            throw new com.tmk.vtcmanager.application.exception.ResourceNotFoundException(
                    "Utilisateur non trouvé: " + userId);
        }
    }

    @Override
    public void assignRealmRole(String userId, String roleName) {
        try {
            RoleRepresentation role = realmResource().roles().get(roleName).toRepresentation();
            usersResource().get(userId).roles().realmLevel().add(Collections.singletonList(role));
            log.info("Rôle '{}' assigné à l'utilisateur {}", roleName, userId);
        } catch (NotFoundException e) {
            throw new com.tmk.vtcmanager.application.exception.ResourceNotFoundException(
                    "Rôle ou utilisateur non trouvé: " + roleName);
        }
    }

    @Override
    public List<UserInfo> getUsersByRole(String roleName) {
        try {
            return realmResource().roles().get(roleName).getUserMembers()
                    .stream()
                    .map(this::toUserInfo)
                    .collect(Collectors.toList());
        } catch (NotFoundException e) {
            return Collections.emptyList();
        }
    }

    @Override
    public void removeRealmRole(String userId, String roleName) {
        try {
            RoleRepresentation role = realmResource().roles().get(roleName).toRepresentation();
            usersResource().get(userId).roles().realmLevel().remove(Collections.singletonList(role));
            log.info("Rôle '{}' retiré de l'utilisateur {}", roleName, userId);
        } catch (NotFoundException e) {
            throw new com.tmk.vtcmanager.application.exception.ResourceNotFoundException(
                    "Rôle ou utilisateur non trouvé: " + roleName);
        }
    }

    // ── Helpers ──

    private UserInfo toUserInfo(UserRepresentation user) {
        return UserInfo.builder()
                .id(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .firstName(user.getFirstName())
                .lastName(user.getLastName())
                .enabled(user.isEnabled())
                .build();
    }

    private String extractUserId(Response response) {
        String location = response.getHeaderString("Location");
        if (location != null) {
            return location.substring(location.lastIndexOf("/") + 1);
        }
        throw new RuntimeException("Impossible d'extraire l'ID utilisateur de la réponse Keycloak");
    }
}
