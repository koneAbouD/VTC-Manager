package com.tmk.vtcmanager.application.usecases.admin;

import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class DeleteUserUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public void execute(String userId) {
        keycloakAdminPort.deleteUser(userId);
    }
}
