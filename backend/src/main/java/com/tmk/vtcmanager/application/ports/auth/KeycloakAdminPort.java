package com.tmk.vtcmanager.application.ports.auth;

import com.tmk.vtcmanager.application.domain.auth.RegisterRequest;
import com.tmk.vtcmanager.application.domain.auth.UserInfo;

import java.util.List;

/**
 * Port pour les opérations d'administration Keycloak (Admin REST API).
 * Gestion des utilisateurs, rôles, mots de passe.
 */
public interface KeycloakAdminPort {

    /**
     * Crée un nouvel utilisateur dans Keycloak.
     */
    UserInfo createUser(RegisterRequest request);

    /**
     * Envoie un email de réinitialisation de mot de passe.
     */
    void sendResetPasswordEmail(String email);

    /**
     * Récupère tous les utilisateurs du realm.
     */
    List<UserInfo> getAllUsers();

    /**
     * Récupère un utilisateur par son ID Keycloak.
     */
    UserInfo getUserById(String userId);

    /**
     * Recherche un utilisateur par email.
     */
    UserInfo getUserByEmail(String email);

    /**
     * Met à jour les informations d'un utilisateur.
     */
    UserInfo updateUser(String userId, UserInfo userInfo);

    /**
     * Supprime un utilisateur.
     */
    void deleteUser(String userId);

    /**
     * Active ou désactive un utilisateur.
     */
    void setUserEnabled(String userId, boolean enabled);

    /**
     * Récupère tous les rôles realm disponibles.
     */
    List<String> getAllRealmRoles();

    /**
     * Récupère les rôles d'un utilisateur.
     */
    List<String> getUserRoles(String userId);

    /**
     * Assigne un rôle realm à un utilisateur.
     */
    void assignRealmRole(String userId, String roleName);

    /**
     * Retire un rôle realm d'un utilisateur.
     */
    void removeRealmRole(String userId, String roleName);

    /**
     * Récupère tous les utilisateurs ayant un rôle realm donné.
     */
    List<UserInfo> getUsersByRole(String roleName);
}
