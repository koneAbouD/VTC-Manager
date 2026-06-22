package com.tmk.vtcmanager.application.usecases.admin;

import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class UpdateUserUseCase {

    private final KeycloakAdminPort keycloakAdminPort;

    public UserInfo execute(String userId, UserInfo userInfo) {
        return keycloakAdminPort.updateUser(userId, userInfo);
    }
}
