package com.tmk.vtcmanager.application.usecases.auth;

import com.tmk.vtcmanager.application.domain.auth.RegisterRequest;
import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class RegisterUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public UserInfo execute(RegisterRequest request) {
        return keycloakAdminPort.createUser(request);
    }
}
