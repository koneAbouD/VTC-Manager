package com.tmk.vtcmanager.application.usecases.admin;

import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class SetUserEnabledUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public void execute(String userId, boolean enabled) {
        keycloakAdminPort.setUserEnabled(userId, enabled);
    }
}
