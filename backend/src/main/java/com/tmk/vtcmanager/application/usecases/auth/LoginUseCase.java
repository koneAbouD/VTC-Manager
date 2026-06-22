package com.tmk.vtcmanager.application.usecases.auth;

import com.tmk.vtcmanager.application.domain.auth.TokenResponse;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAuthPort;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class LoginUseCase {

    private final KeycloakAuthPort keycloakAuthPort;

    public TokenResponse execute(String username, String password) {
        return keycloakAuthPort.login(username, password);
    }
}
