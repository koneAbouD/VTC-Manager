package com.tmk.vtcmanager.application.usecases.auth;

import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class ForgotPasswordUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public void execute(String email) {
        keycloakAdminPort.sendResetPasswordEmail(email);
    }
}
