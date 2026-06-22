package com.tmk.vtcmanager.application.usecases.auth;

import com.tmk.vtcmanager.application.ports.auth.KeycloakAuthPort;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class LogoutUseCase {

    private final KeycloakAuthPort keycloakAuthPort;

    public void execute(String refreshToken) {
        keycloakAuthPort.logout(refreshToken);
    }
}
