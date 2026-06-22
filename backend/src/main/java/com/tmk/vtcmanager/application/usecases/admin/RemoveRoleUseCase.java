package com.tmk.vtcmanager.application.usecases.admin;

import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class RemoveRoleUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public void execute(String userId, String roleName) {
        keycloakAdminPort.removeRealmRole(userId, roleName);
    }
}
